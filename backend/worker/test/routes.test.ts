import { exports } from "cloudflare:workers";
import { describe, expect, it } from "vitest";

const ADMIN = "admin-teste";
const base = "http://denden.test";

async function call(
  method: string,
  path: string,
  opts: { key?: string; admin?: string; body?: unknown; raw?: string } = {},
) {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (opts.key) headers["X-DenDen-Key"] = opts.key;
  if (opts.admin) headers["X-DenDen-Admin"] = opts.admin;
  const res = await exports.default.fetch(`${base}${path}`, {
    method,
    headers,
    body: opts.raw ?? (opts.body === undefined ? undefined : JSON.stringify(opts.body)),
  });
  const text = await res.text();
  expect(text).not.toContain("SEGREDO-DE-TESTE");
  return { status: res.status, json: text ? JSON.parse(text) : null };
}

async function newKey(name: string): Promise<string> {
  const r = await call("POST", "/admin/chaves", { admin: ADMIN, body: { name } });
  expect(r.status).toBe(200);
  return r.json.key;
}

const TRACKS = [
  { mid: "0", trackName: "video" },
  { mid: "1", trackName: "audio" },
];

describe("rotas do Worker", () => {
  it("sem chave → 401; admin com chave comum → 403", async () => {
    expect((await call("POST", "/salas", { body: {} })).json.error).toBe("chave_invalida");
    const ana = await newKey("Ana");
    const r = await call("POST", "/admin/chaves", { admin: ana, body: { name: "x" } });
    expect(r.status).toBe(403);
    expect(r.json.error).toBe("nao_e_admin");
  });

  it("criar, entrar, responder, relatar, consultar e encerrar", async () => {
    const ana = await newKey("Ana");
    const bia = await newKey("Bia");
    const sala = await call("POST", "/salas", {
      key: ana,
      body: { profile: "high", offerSdp: "OFERTA", tracks: TRACKS },
    });
    expect(sala.status).toBe(200);
    expect(sala.json.answerSdp).toBe("RESP_SFU");
    expect(sala.json.iceServers[0].urls).toBe("stun:stun.cloudflare.com:3478");
    const code = sala.json.code as string;

    const entrar = await call("POST", `/salas/${code}/entrar`, { key: bia, body: {} });
    expect(entrar.status).toBe(200);
    expect(entrar.json.offerSdp).toBe("OFERTA_SFU");

    const resp = await call("POST", `/salas/${code}/resposta`, {
      key: bia,
      body: { viewerId: entrar.json.viewerId, answerSdp: "RESP_BIA" },
    });
    expect(resp.status).toBe(200);

    const rel = await call("POST", `/salas/${code}/relatorio`, {
      key: bia,
      body: { who: entrar.json.viewerId, bytes: 1000 },
    });
    expect(rel.json).toMatchObject({ level: "normal", profile: "high", warnings: [] });

    expect((await call("GET", `/salas/${code}`, { key: bia })).json).toEqual({
      state: "live",
      viewers: 1,
    });
    const consumo = await call("GET", "/consumo", { key: bia });
    expect(consumo.json.notice).toContain("não é um limite garantido");
    expect(consumo.json.reportedEgressBytes).toBe(1000);

    expect((await call("POST", `/salas/${code}/encerrar`, { key: ana })).status).toBe(200);
    expect((await call("GET", `/salas/${code}`, { key: bia })).json.state).toBe("ended");
  });

  it("emergência: encerra e recusa novas com 503", async () => {
    const ana = await newKey("Ana");
    await call("POST", "/admin/emergencia", { admin: ADMIN, body: { on: true } });
    const r = await call("POST", "/salas", {
      key: ana,
      body: { profile: "high", offerSdp: "O", tracks: TRACKS },
    });
    expect(r.status).toBe(503);
    expect(r.json.error).toBe("emergencia");
    await call("POST", "/admin/emergencia", { admin: ADMIN, body: { on: false } });
  });

  it("revogar chave pelo admin", async () => {
    const r = await call("POST", "/admin/chaves", { admin: ADMIN, body: { name: "Caio" } });
    await call("POST", `/admin/chaves/${r.json.hash}/revogar`, { admin: ADMIN });
    const s = await call("POST", "/salas", {
      key: r.json.key,
      body: { profile: "high", offerSdp: "O", tracks: TRACKS },
    });
    expect(s.status).toBe(401);
  });

  it("corpo inválido → 400; rota desconhecida → 404", async () => {
    const ana = await newKey("Ana");
    expect((await call("POST", "/salas", { key: ana, body: { profile: "ultra" } })).status).toBe(400);
    expect((await call("GET", "/nada", { key: ana })).status).toBe(404);
  });

  it("GET /ice devolve servidores ICE antes de abrir a conexão", async () => {
    const ana = await newKey("Ana");
    const r = await call("GET", "/ice", { key: ana });
    expect(r.status).toBe(200);
    expect(r.json.iceServers).toEqual([{ urls: "stun:stun.cloudflare.com:3478" }]);
    expect((await call("GET", "/ice", { key: "errada" })).status).toBe(401);
  });

  it("admin: lista chaves e vê o consumo; chave comum não vê", async () => {
    await newKey("Dani");
    const keys = await call("GET", "/admin/chaves", { admin: ADMIN });
    expect(keys.status).toBe(200);
    expect(keys.json.keys.some((k: { name: string }) => k.name === "Dani")).toBe(true);
    const u = await call("GET", "/admin/consumo", { admin: ADMIN });
    expect(u.status).toBe(200);
    expect(u.json.notice).toContain("não é um limite garantido");
    const ana = await newKey("Ana");
    expect((await call("GET", "/admin/consumo", { admin: ana })).status).toBe(403);
  });

  it("admin: limite inválido → 400 config_invalida", async () => {
    const r = await call("POST", "/admin/config", { admin: ADMIN, body: { budgetGb: 0 } });
    expect(r.status).toBe(400);
    expect(r.json.error).toBe("config_invalida");
  });

  it("admin: campos desconhecidos na configuração são recusados", async () => {
    const r = await call("POST", "/admin/config", {
      admin: ADMIN,
      body: { budgetGb: 800, hack: "x" },
    });
    expect(r.status).toBe(400);
    expect(r.json.error).toBe("pedido_invalido");
    expect(r.json.message).toBe("Campo desconhecido: hack.");
    const ok = await call("POST", "/admin/config", { admin: ADMIN, body: { budgetGb: 800 } });
    expect(ok.status).toBe(200);
    expect(ok.json.budgetGb).toBe(800);
  });
});

describe("rotas de administração recusam entradas inválidas", () => {
  const ROTAS = ["/admin/chaves", "/admin/config", "/admin/confirmado", "/admin/emergencia"];

  async function expect400(path: string, opts: { body?: unknown; raw?: string }, message?: string) {
    const r = await call("POST", path, { admin: ADMIN, ...opts });
    expect(r.status, `${path} ${opts.raw ?? JSON.stringify(opts.body)}`).toBe(400);
    expect(r.json.error).toBeTypeOf("string");
    if (message) expect(r.json.message).toBe(message);
    // Nada de detalhes internos na mensagem.
    expect(r.json.message).not.toMatch(/SyntaxError|JSON|undefined|Unexpected|stack/i);
    return r;
  }

  it("JSON quebrado → 400 Formato inválido", async () => {
    for (const path of ROTAS) await expect400(path, { raw: "{quebrado" }, "Formato inválido.");
  });

  it("JSON que não é objeto → 400 Formato inválido", async () => {
    for (const path of ROTAS) {
      for (const raw of ["[]", '["x"]', "null", "42", '"texto"', "true"]) {
        await expect400(path, { raw }, "Formato inválido.");
      }
    }
  });

  it("campos extras → 400 em todas as rotas", async () => {
    await expect400("/admin/chaves", { body: { name: "Eva", admin: true } }, "Campo desconhecido: admin.");
    await expect400("/admin/emergencia", { body: { on: false, x: 1 } }, "Campo desconhecido: x.");
    await expect400(
      "/admin/confirmado",
      { body: { month: "2026-10", confirmedGb: 1, extra: 1 } },
      "Campo desconhecido: extra.",
    );
    const k = await newKey("Fabi");
    const hash = (await call("GET", "/admin/chaves", { admin: ADMIN })).json.keys.find(
      (x: { name: string }) => x.name === "Fabi",
    ).hash;
    await expect400(`/admin/chaves/${hash}/revogar`, { body: { motivo: "x" } }, "Campo desconhecido: motivo.");
    // A chave continua valendo depois do pedido recusado.
    expect((await call("GET", "/ice", { key: k })).status).toBe(200);
  });

  it("chaves: nome com tipo errado ou só espaços → 400", async () => {
    for (const name of [123, null, true, ["Ana"], { n: "Ana" }, "", "   "]) {
      await expect400("/admin/chaves", { body: { name } });
    }
  });

  it("revogar chave que não existe → 404", async () => {
    const r = await call("POST", "/admin/chaves/naoexiste/revogar", { admin: ADMIN });
    expect(r.status).toBe(404);
    expect(r.json.error).toBe("chave_inexistente");
  });

  it("rotas que mudam algo só aceitam POST", async () => {
    const r = await call("POST", "/admin/chaves", { admin: ADMIN, body: { name: "Gil" } });
    expect((await call("GET", `/admin/chaves/${r.json.hash}/revogar`, { admin: ADMIN })).status).toBe(404);
    expect((await call("GET", "/ice", { key: r.json.key })).status).toBe(200);
    for (const path of ["/admin/config", "/admin/confirmado", "/admin/emergencia"]) {
      expect((await call("GET", path, { admin: ADMIN })).status, path).toBe(404);
      expect((await call("DELETE", path, { admin: ADMIN })).status, path).toBe(404);
    }
  });

  it("config: tipos errados, negativos e infinitos → 400", async () => {
    const ruins: unknown[] = [
      { budgetGb: "900" },
      { budgetGb: -1 },
      { budgetGb: null },
      { freeGb: -5 },
      { usdPerGb: 0 },
      { brlPerUsd: [5] },
      { ceilingPercent: 99 },
      { maxSessionHours: "6" },
      { warnPercents: "50,75" },
      { warnPercents: [50, -1] },
      { warnPercents: [50, "75"] },
    ];
    for (const body of ruins) await expect400("/admin/config", { body });
    // JSON aceita 1e999, que vira Infinity no Worker.
    for (const campo of ["budgetGb", "freeGb", "usdPerGb", "brlPerUsd", "ceilingPercent", "maxSessionHours"]) {
      await expect400("/admin/config", { raw: `{"${campo}": 1e999}` });
    }
    await expect400("/admin/config", { raw: '{"warnPercents": [1e999]}' });
    await expect400("/admin/config", { raw: '{"budgetGb": -1e999}' });
  });

  it("confirmado: mês, tipos, negativos e infinitos → 400", async () => {
    for (const month of [undefined, 202610, "", "outubro", "2026-13", "2026-1", "2026-10-01"]) {
      await expect400("/admin/confirmado", { body: { month, confirmedGb: 1 } });
    }
    for (const v of ["10", null, -1, true, [1]]) {
      await expect400("/admin/confirmado", { body: { month: "2026-10", confirmedGb: v } });
      await expect400("/admin/confirmado", { body: { month: "2026-10", billedBrl: v } });
    }
    await expect400("/admin/confirmado", { raw: '{"month": "2026-10", "confirmedGb": 1e999}' });
    await expect400("/admin/confirmado", { raw: '{"month": "2026-10", "billedBrl": -1e999}' });
    const ok = await call("POST", "/admin/confirmado", {
      admin: ADMIN,
      body: { month: "2026-10", confirmedGb: 12.5, billedBrl: 0 },
    });
    expect(ok.status).toBe(200);
  });

  it("emergência: tipo errado → 400", async () => {
    for (const on of ["true", 1, null, undefined]) await expect400("/admin/emergencia", { body: { on } });
  });

  it("corpo vazio continua valendo onde não há campos obrigatórios", async () => {
    const r = await call("POST", "/admin/chaves", { admin: ADMIN, body: { name: "Hugo" } });
    expect((await call("POST", `/admin/chaves/${r.json.hash}/revogar`, { admin: ADMIN })).status).toBe(200);
    expect((await call("POST", "/admin/config", { admin: ADMIN })).status).toBe(200);
  });
});
