import { exports } from "cloudflare:workers";
import { describe, expect, it } from "vitest";

const ADMIN = "admin-teste";
const base = "http://denden.test";

async function call(
  method: string,
  path: string,
  opts: { key?: string; admin?: string; body?: unknown } = {},
) {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (opts.key) headers["X-DenDen-Key"] = opts.key;
  if (opts.admin) headers["X-DenDen-Admin"] = opts.admin;
  const res = await exports.default.fetch(`${base}${path}`, {
    method,
    headers,
    body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
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
});
