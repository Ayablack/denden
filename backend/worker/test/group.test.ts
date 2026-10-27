import { beforeEach, describe, expect, it } from "vitest";
import { Group, GroupError, MemoryStore } from "../src/group";
import { RealtimeError, type LocalTrack, type RealtimePort } from "../src/realtime";

const GB = 1e9;
const TRACKS: LocalTrack[] = [
  { mid: "0", trackName: "video" },
  { mid: "1", trackName: "audio" },
];

class FakeRealtime implements RealtimePort {
  sessions = 0;
  pushed: Array<{ sessionId: string; offerSdp: string; tracks: LocalTrack[] }> = [];
  pulled: Array<{ sessionId: string; remote: string; names: string[] }> = [];
  renegotiated: Array<{ sessionId: string; sdp: string }> = [];
  closed: Array<{ sessionId: string; mids: string[] }> = [];
  failNext = false;

  async newSession() {
    if (this.failNext) {
      this.failNext = false;
      throw new RealtimeError(500, "internal_error", "falhou");
    }
    return `S${++this.sessions}`;
  }
  async pushTracks(sessionId: string, offerSdp: string, tracks: LocalTrack[]) {
    this.pushed.push({ sessionId, offerSdp, tracks });
    return { answerSdp: `RESP-${sessionId}` };
  }
  async pullTracks(sessionId: string, remote: string, names: string[]) {
    this.pulled.push({ sessionId, remote, names });
    return { offerSdp: `OFERTA-${sessionId}`, requiresImmediateRenegotiation: true };
  }
  async renegotiate(sessionId: string, sdp: string) {
    this.renegotiated.push({ sessionId, sdp });
  }
  async closeTracks(sessionId: string, mids: string[]) {
    this.closed.push({ sessionId, mids });
  }
  /** Estado que o SFU falso informa para as trilhas de quem transmite. */
  sfu: "active" | "inactive" | "error" = "active";
  sessionChecks = 0;
  async getSession(_sessionId: string) {
    this.sessionChecks++;
    if (this.sfu === "error") throw new RealtimeError(503, "indisponivel", "falhou");
    return {
      tracks: [
        { location: "local", mid: "0", trackName: "video", status: this.sfu },
        { location: "local", mid: "1", trackName: "audio", status: this.sfu },
      ],
    };
  }
}

async function expectGroupError(p: Promise<unknown>, status: number, code: string) {
  const e = (await p.catch((x) => x)) as GroupError;
  expect(e).toBeInstanceOf(GroupError);
  expect({ status: e.status, code: e.code }).toEqual({ status, code });
}

describe("grupo: salas, espectadores, consumo e limites", () => {
  let rt: FakeRealtime;
  let g: Group;
  let ana: string;
  let bia: string;
  const T0 = Date.UTC(2026, 9, 23, 12, 0, 0);

  beforeEach(async () => {
    rt = new FakeRealtime();
    g = new Group(new MemoryStore(), rt, {});
    ana = (await g.addKey("Ana")).key;
    bia = (await g.addKey("Bia")).key;
  });

  const create = (now = T0, key = ana) =>
    g.createRoom(key, { profile: "high", offerSdp: "OFERTA-ANA", tracks: TRACKS }, now);

  it("fluxo feliz: criar, entrar e responder", async () => {
    const room = await create();
    expect(room.code).toMatch(/^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$/);
    expect(room.answerSdp).toBe("RESP-S1");
    expect(rt.pushed[0]).toEqual({ sessionId: "S1", offerSdp: "OFERTA-ANA", tracks: TRACKS });

    const join = await g.joinRoom(bia, room.code.toLowerCase(), "ip-b", T0 + 1000);
    expect(join.offerSdp).toBe("OFERTA-S2");
    expect(rt.pulled[0]).toEqual({ sessionId: "S2", remote: "S1", names: ["video", "audio"] });

    await g.answer(bia, room.code, join.viewerId, "RESP-BIA", T0 + 2000);
    expect(rt.renegotiated).toEqual([{ sessionId: "S2", sdp: "RESP-BIA" }]);
    expect(await g.roomState(room.code)).toEqual({ state: "live", viewers: 1 });
  });

  it("aceita até 5 espectadores e recusa o sexto", async () => {
    const { code } = await create();
    for (let i = 0; i < 5; i++) await g.joinRoom(bia, code, `ip${i}`, T0);
    await expectGroupError(g.joinRoom(bia, code, "ip6", T0), 409, "sala_cheia");
  });

  it("código errado 5 vezes bloqueia a chave por 1 min", async () => {
    await create();
    for (let i = 0; i < 5; i++) {
      await expectGroupError(g.joinRoom(bia, "ZZZZZZ", "ip", T0 + i), 404, "sala_inexistente");
    }
    await expectGroupError(g.joinRoom(bia, "ZZZZZZ", "ip", T0 + 10), 429, "bloqueado");
  });

  it("chave revogada ou desconhecida não cria nem entra", async () => {
    const { code } = await create();
    const { hash } = await g.addKey("Caio");
    await g.revokeKey(hash);
    await expectGroupError(create(T0, "chave-errada"), 401, "chave_invalida");
    await expectGroupError(g.joinRoom("chave-errada", code, "ip", T0), 401, "chave_invalida");
  });

  it("não trata propriedades herdadas como chaves ao revogar", async () => {
    await expectGroupError(g.revokeKey("__proto__"), 404, "chave_inexistente");
    await expectGroupError(g.revokeKey("constructor"), 404, "chave_inexistente");
  });

  it("guarda somente mid e trackName das trilhas", async () => {
    const store = new MemoryStore();
    const local = new Group(store, rt, {});
    const key = (await local.addKey("Ana")).key;
    await local.createRoom(
      key,
      {
        profile: "high",
        offerSdp: "OFERTA",
        tracks: [{ mid: "0", trackName: "video", extra: "não guardar" } as LocalTrack & { extra: string }],
      },
      T0,
    );
    const state = (await store.get<{ rooms: Record<string, { tracks: unknown }> }>("state"))!;
    expect(Object.values(state.rooms)[0].tracks).toEqual([{ mid: "0", trackName: "video" }]);
  });

  it("consumo: soma o que cada espectador recebeu; vale a maior estimativa", async () => {
    const { code } = await create();
    const v1 = (await g.joinRoom(bia, code, "a", T0)).viewerId;
    const v2 = (await g.joinRoom(bia, code, "b", T0)).viewerId;
    await g.report(ana, code, "publisher", 0, T0);
    // 10 s depois: cada espectador recebeu 5 MB (relatórios cumulativos).
    await g.report(bia, code, v1, 5_000_000, T0 + 10_000);
    const repView2 = await g.report(bia, code, v2, 5_000_000, T0 + 10_000);
    const repPub = await g.report(ana, code, "publisher", 9_000_000, T0 + 10_000);

    expect(repView2.roomEgressBytes).toBe(10_000_000);
    expect(repPub.roomEgressBytes).toBe(10_000_000);
    expect(repPub.monthEgressBytes).toBe(15_000_000); // 6 Mbps * 2 * 10s = 15MB

    const u = await g.usage(ana, T0 + 10_000);
    expect(u.reportedEgressBytes).toBe(10_000_000);
    // Servidor: 6 Mbps × 2 espectadores × 10 s = 15 MB > 10 MB relatados.
    expect(u.serverEgressBytes).toBe(15_000_000);
    expect(u.effectiveEgressBytes).toBe(15_000_000);
    expect(u.rooms[0].viewers.map((v) => v.receivedBytes)).toEqual([5_000_000, 5_000_000]);
  });

  it("troca de perfil aceita; o perfil antigo é usado no intervalo anterior", async () => {
    const { code } = await create(); // high
    await g.joinRoom(bia, code, "a", T0); // 1 viewer
    await g.report(ana, code, "publisher", 0, T0);

    // Passa-se 10s. O perfil ainda é high.
    // 6 Mbps / 8 * 10s = 7.5 MB
    const r1 = await g.report(ana, code, "publisher", 1_000_000, T0 + 10_000, "medium");
    expect(r1.profile).toBe("medium");

    // Mais 10s. O perfil agora é medium.
    // 3.5 Mbps / 8 * 10s = 4.375 MB
    const r2 = await g.report(ana, code, "publisher", 2_000_000, T0 + 20_000);

    const u = await g.usage(ana, T0 + 20_000);
    // 7.5 MB + 4.375 MB = 11.875 MB
    expect(u.serverEgressBytes).toBe(11_875_000);
    expect(r2.monthEgressBytes).toBe(11_875_000);
  });

  it("recusa criar sala quando o mês chegou a 100% do orçamento", async () => {
    await g.setConfig({ budgetGb: 1 });
    const { code } = await create();
    const v = (await g.joinRoom(bia, code, "a", T0)).viewerId;
    await g.report(bia, code, v, 1 * GB, T0 + 1000);
    await expectGroupError(create(T0 + 2000, bia), 403, "orcamento");
  });

  it("a 100% a sessão ativa passa para Economia; a 105% encerra após 60 s", async () => {
    await g.setConfig({ budgetGb: 1 });
    const { code } = await create();
    const v = (await g.joinRoom(bia, code, "a", T0)).viewerId;

    const blocked = await g.report(bia, code, v, 1.0 * GB, T0 + 1000);
    expect(blocked.level).toBe("blocked");
    expect(blocked.profile).toBe("economy");
    expect(blocked.warnings).toEqual([50, 75, 90, 100]);

    // economy forçado quando bloqueado (mesmo se o publisher pedir "high")
    const rPub = await g.report(ana, code, "publisher", 0, T0 + 1000, "high");
    expect(rPub.level).toBe("blocked");
    expect(rPub.profile).toBe("economy");

    const ceiling = await g.report(bia, code, v, 1.06 * GB, T0 + 2000);
    expect(ceiling.level).toBe("ceiling");
    expect(ceiling.endsAtMs).toBe(T0 + 2000 + 60_000);

    // O transmissor segue relatando (senão a sala cairia por inatividade).
    await g.report(ana, code, "publisher", 0, T0 + 2000 + 58_000);
    await g.tick(T0 + 2000 + 59_000);
    expect((await g.roomState(code)).state).toBe("live");
    await g.tick(T0 + 2000 + 60_000);
    expect((await g.roomState(code)).state).toBe("ended");
    expect((await g.usage(ana, T0 + 70_000)).history[0].reason).toBe("teto");
  });

  it("encerra a sala se o transmissor some por 30 s", async () => {
    const { code } = await create();
    await g.report(ana, code, "publisher", 0, T0);
    await g.tick(T0 + 29_000);
    expect((await g.roomState(code)).state).toBe("live");
    await g.tick(T0 + 31_000);
    expect((await g.roomState(code)).state).toBe("ended");
    expect(rt.closed).toContainEqual({ sessionId: "S1", mids: ["0", "1"] });
  });

  it("espectador sem relatório por 30 s libera a vaga", async () => {
    const { code } = await create();
    for (let i = 0; i < 5; i++) await g.joinRoom(bia, code, `ip${i}`, T0);
    await g.report(ana, code, "publisher", 0, T0 + 31_000);
    await g.tick(T0 + 31_000);
    expect((await g.roomState(code)).viewers).toBe(0);
    await g.joinRoom(bia, code, "novo", T0 + 32_000);
  });

  it("só o transmissor encerra a própria sala", async () => {
    const { code } = await create();
    await expectGroupError(g.endRoom(bia, code, T0), 403, "nao_e_o_transmissor");
    await g.endRoom(ana, code, T0);
    expect((await g.roomState(code)).state).toBe("ended");
    await expectGroupError(g.joinRoom(bia, code, "ip", T0), 404, "sala_inexistente");
  });

  it("emergência encerra todas as salas e recusa novas", async () => {
    const { code } = await create();
    await g.setEmergency(true, T0);
    expect((await g.roomState(code)).state).toBe("ended");
    await expectGroupError(create(T0 + 1), 503, "emergencia");
    await g.setEmergency(false, T0 + 2);
    await create(T0 + 3);
  });

  it("erro do provedor vira 502 sem sala criada", async () => {
    rt.failNext = true;
    await expectGroupError(create(), 502, "provedor");
    expect((await g.usage(ana, T0)).rooms).toEqual([]);
  });

  it("admin lista as chaves (nome, hash, revogada) sem expor a chave", async () => {
    const { hash } = await g.addKey("Caio");
    await g.revokeKey(hash);
    const keys = await g.listKeys();
    expect(keys.map((k) => k.name).sort()).toEqual(["Ana", "Bia", "Caio"]);
    expect(keys.find((k) => k.name === "Caio")).toEqual({ name: "Caio", hash, revoked: true });
    expect(JSON.stringify(keys)).not.toContain(ana);
  });

  it("consumo para o admin: mesmo painel, sem precisar de chave pessoal", async () => {
    const { code } = await create();
    const v = (await g.joinRoom(bia, code, "a", T0)).viewerId;
    await g.report(bia, code, v, 2 * GB, T0 + 1000);
    const u = await g.adminUsage(T0 + 1000);
    expect(u.reportedEgressBytes).toBe(2 * GB);
    expect(u.rooms[0].viewers[0].receivedBytes).toBe(2 * GB);
  });

  it("indicadores de aviso: quais limites já foram atingidos", async () => {
    await g.setConfig({ budgetGb: 10 });
    const { code } = await create();
    const v = (await g.joinRoom(bia, code, "a", T0)).viewerId;
    await g.report(bia, code, v, 8 * GB, T0 + 1000);
    const u = await g.usage(ana, T0 + 1000);
    expect(u.warnings).toEqual([
      { percent: 50, reached: true },
      { percent: 75, reached: true },
      { percent: 90, reached: false },
      { percent: 100, reached: false },
    ]);
    expect(u.percentOfBudget).toBeCloseTo(80, 5);
  });

  it("custo: estimado separado do confirmado e do faturado", async () => {
    await g.setConfirmed("2026-10", 12.5, 0);
    const u = await g.usage(ana, T0);
    expect(u.estimatedCostUsd).toBe(0);
    expect(u.confirmedGb).toBe(12.5);
    expect(u.billedBrl).toBe(0);
  });

  it("limites inválidos são recusados", async () => {
    await expectGroupError(g.setConfig({ budgetGb: -1 }), 400, "config_invalida");
    await expectGroupError(g.setConfig({ warnPercents: [50, 150] }), 400, "config_invalida");
    await expectGroupError(g.setConfig({ ceilingPercent: 90 }), 400, "config_invalida");
    await expectGroupError(g.setConfig({ usdPerGb: Number.NaN }), 400, "config_invalida");
    const ok = await g.setConfig({ warnPercents: [75, 50], budgetGb: 500 });
    expect(ok.warnPercents).toEqual([50, 75]);
    expect(ok.budgetGb).toBe(500);
  });
});

describe("grupo: sinal no SFU e duração máxima", () => {
  let rt: FakeRealtime;
  let g: Group;
  let ana: string;
  const T0 = Date.UTC(2026, 9, 26, 12, 0, 0);
  const MIN = 60_000;
  const H = 3_600_000;

  beforeEach(async () => {
    rt = new FakeRealtime();
    g = new Group(new MemoryStore(), rt, {});
    ana = (await g.addKey("Ana")).key;
  });

  const create = () =>
    g.createRoom(ana, { profile: "high", offerSdp: "O", tracks: TRACKS }, T0);

  /** O app de quem transmite segue relatando (senão cai por inatividade). */
  async function aliveUntil(code: string, until: number, step = 20_000) {
    for (let t = T0 + step; t <= until; t += step) {
      await g.report(ana, code, "publisher", 0, t);
      await g.tick(t);
    }
  }

  it("trilha ativa no SFU: a sala segue, e a checagem é a cada 60 s", async () => {
    const { code } = await create();
    await aliveUntil(code, T0 + 5 * MIN);
    expect((await g.roomState(code)).state).toBe("live");
    expect(rt.sessionChecks).toBeGreaterThanOrEqual(4);
    expect(rt.sessionChecks).toBeLessThanOrEqual(6);
  });

  it("duas checagens seguidas sem trilha ativa encerram a sala", async () => {
    const { code } = await create();
    rt.sfu = "inactive";
    await aliveUntil(code, T0 + 61_000);
    expect((await g.roomState(code)).state).toBe("live");
    await aliveUntil(code, T0 + 2 * MIN + 1_000);
    expect((await g.roomState(code)).state).toBe("ended");
    const u = await g.usage(ana, T0 + 3 * MIN);
    expect(u.history[0].reason).toBe("sem_sinal");
    expect(rt.closed).toContainEqual({ sessionId: "S1", mids: ["0", "1"] });
  });

  it("uma falta seguida de trilha ativa zera a contagem", async () => {
    const { code } = await create();
    rt.sfu = "inactive";
    await aliveUntil(code, T0 + 61_000);
    rt.sfu = "active";
    await aliveUntil(code, T0 + 2 * MIN + 1_000);
    rt.sfu = "inactive";
    await aliveUntil(code, T0 + 3 * MIN + 1_000);
    expect((await g.roomState(code)).state).toBe("live");
  });

  it("erro passageiro da API do SFU não conta como falta", async () => {
    const { code } = await create();
    rt.sfu = "error";
    await aliveUntil(code, T0 + 5 * MIN);
    expect((await g.roomState(code)).state).toBe("live");
  });

  it("duração máxima padrão de 6 h: aviso no relatório e fim no limite", async () => {
    const { code } = await create();
    const r = await g.report(ana, code, "publisher", 0, T0 + 1000);
    expect(r.sessionEndsAtMs).toBe(T0 + 6 * H);
    await g.report(ana, code, "publisher", 0, T0 + 6 * H - 1000);
    await g.tick(T0 + 6 * H - 1000);
    expect((await g.roomState(code)).state).toBe("live");
    await g.report(ana, code, "publisher", 0, T0 + 6 * H);
    await g.tick(T0 + 6 * H);
    expect((await g.roomState(code)).state).toBe("ended");
    expect((await g.usage(ana, T0 + 7 * H)).history[0].reason).toBe("duracao_maxima");
  });

  it("duração máxima configurável e validada", async () => {
    await expectGroupError(g.setConfig({ maxSessionHours: 0 }), 400, "config_invalida");
    await expectGroupError(g.setConfig({ maxSessionHours: 25 }), 400, "config_invalida");
    expect((await g.setConfig({ maxSessionHours: 2 })).maxSessionHours).toBe(2);
    const { code } = await create();
    const r = await g.report(ana, code, "publisher", 0, T0 + 1000);
    expect(r.sessionEndsAtMs).toBe(T0 + 2 * H);
  });
});

describe("grupo: estado salvo por uma versão anterior", () => {
  it("config antiga sem maxSessionHours recebe o padrão (Worker já implantado)", async () => {
    const store = new MemoryStore();
    const old = new Group(store, new FakeRealtime(), {});
    const ana = (await old.addKey("Ana")).key;
    // Simula o que o Worker antigo gravou: config sem o campo novo.
    const raw = (await store.get<{ config: Record<string, unknown> }>("state"))!;
    delete raw.config.maxSessionHours;
    await store.put("state", raw);

    const g = new Group(store, new FakeRealtime(), {});
    const T0 = Date.UTC(2026, 9, 26, 12);
    const { code } = await g.createRoom(
      ana,
      { profile: "high", offerSdp: "O", tracks: TRACKS },
      T0,
    );
    const r = await g.report(ana, code, "publisher", 0, T0 + 1000);
    expect(r.sessionEndsAtMs).toBe(T0 + 6 * 3_600_000);
    expect((await g.setConfig({ budgetGb: 800 })).maxSessionHours).toBe(6);
  });
});
