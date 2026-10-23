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

  it("consumo: soma o que cada espectador recebeu; vale a maior estimativa", async () => {
    const { code } = await create();
    const v1 = (await g.joinRoom(bia, code, "a", T0)).viewerId;
    const v2 = (await g.joinRoom(bia, code, "b", T0)).viewerId;
    await g.report(ana, code, "publisher", 0, T0);
    // 10 s depois: cada espectador recebeu 5 MB (relatórios cumulativos).
    await g.report(bia, code, v1, 5_000_000, T0 + 10_000);
    await g.report(bia, code, v2, 5_000_000, T0 + 10_000);
    await g.report(ana, code, "publisher", 9_000_000, T0 + 10_000);
    const u = await g.usage(ana, T0 + 10_000);
    expect(u.reportedEgressBytes).toBe(10_000_000);
    // Servidor: 6 Mbps × 2 espectadores × 10 s = 15 MB > 10 MB relatados.
    expect(u.serverEgressBytes).toBe(15_000_000);
    expect(u.effectiveEgressBytes).toBe(15_000_000);
    expect(u.rooms[0].viewers.map((v) => v.receivedBytes)).toEqual([5_000_000, 5_000_000]);
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
