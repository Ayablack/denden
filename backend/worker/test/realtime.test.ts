import { describe, expect, it } from "vitest";
import { RealtimeClient, RealtimeError, iceServers } from "../src/realtime";

type Call = { url: string; method: string; auth: string | null; body: unknown };

function fakeFetch(responses: Array<{ status?: number; json: unknown }>) {
  const calls: Call[] = [];
  const fetcher = async (input: RequestInfo | URL, init?: RequestInit) => {
    calls.push({
      url: String(input),
      method: init?.method ?? "GET",
      auth: new Headers(init?.headers).get("Authorization"),
      body: init?.body ? JSON.parse(String(init.body)) : undefined,
    });
    const r = responses.shift()!;
    return new Response(JSON.stringify(r.json), { status: r.status ?? 200 });
  };
  return { calls, fetcher: fetcher as typeof fetch };
}

const BASE = "https://rtc.live.cloudflare.com/v1/apps/APP";

describe("cliente do Realtime", () => {
  it("cria sessão com o Bearer certo", async () => {
    const f = fakeFetch([{ json: { sessionId: "S1" } }]);
    const rt = new RealtimeClient("APP", "SEGREDO", f.fetcher);
    expect(await rt.newSession()).toBe("S1");
    expect(f.calls[0]).toMatchObject({
      url: `${BASE}/sessions/new`,
      method: "POST",
      auth: "Bearer SEGREDO",
    });
  });

  it("publica trilhas locais com a oferta e devolve a resposta SDP", async () => {
    const f = fakeFetch([
      { json: { sessionDescription: { type: "answer", sdp: "RESP" }, tracks: [] } },
    ]);
    const rt = new RealtimeClient("APP", "T", f.fetcher);
    const r = await rt.pushTracks("S1", "OFERTA", [{ mid: "0", trackName: "video" }]);
    expect(r.answerSdp).toBe("RESP");
    expect(f.calls[0].url).toBe(`${BASE}/sessions/S1/tracks/new`);
    expect(f.calls[0].body).toEqual({
      sessionDescription: { type: "offer", sdp: "OFERTA" },
      tracks: [{ location: "local", mid: "0", trackName: "video" }],
    });
  });

  it("assina trilhas remotas e devolve a oferta do SFU", async () => {
    const f = fakeFetch([
      {
        json: {
          requiresImmediateRenegotiation: true,
          sessionDescription: { type: "offer", sdp: "OFERTA_SFU" },
          tracks: [{ trackName: "video", mid: "0", sessionId: "P" }],
        },
      },
    ]);
    const rt = new RealtimeClient("APP", "T", f.fetcher);
    const r = await rt.pullTracks("V1", "P", ["video", "audio"]);
    expect(r).toEqual({ offerSdp: "OFERTA_SFU", requiresImmediateRenegotiation: true });
    expect(f.calls[0].body).toEqual({
      tracks: [
        { location: "remote", sessionId: "P", trackName: "video" },
        { location: "remote", sessionId: "P", trackName: "audio" },
      ],
    });
  });

  it("renegocia com PUT e a resposta do cliente", async () => {
    const f = fakeFetch([{ json: {} }]);
    await new RealtimeClient("APP", "T", f.fetcher).renegotiate("V1", "RESP_CLIENTE");
    expect(f.calls[0]).toMatchObject({
      url: `${BASE}/sessions/V1/renegotiate`,
      method: "PUT",
      body: { sessionDescription: { type: "answer", sdp: "RESP_CLIENTE" } },
    });
  });

  it("fecha trilhas à força, sem precisar de SDP", async () => {
    const f = fakeFetch([{ json: { tracks: [] } }]);
    await new RealtimeClient("APP", "T", f.fetcher).closeTracks("S1", ["0", "1"]);
    expect(f.calls[0]).toMatchObject({
      url: `${BASE}/sessions/S1/tracks/close`,
      method: "PUT",
      body: { tracks: [{ mid: "0" }, { mid: "1" }], force: true },
    });
  });

  it("erro HTTP ou errorCode vira RealtimeError sem vazar o segredo", async () => {
    const f = fakeFetch([{ status: 401, json: { errorCode: "unauthorized" } }]);
    const rt = new RealtimeClient("APP", "SEGREDO-XYZ", f.fetcher);
    const e = await rt.newSession().catch((x) => x);
    expect(e).toBeInstanceOf(RealtimeError);
    expect(e.status).toBe(401);
    expect(String(e)).not.toContain("SEGREDO-XYZ");

    const g = fakeFetch([{ json: { errorCode: "bad_sdp", errorDescription: "x" } }]);
    const e2 = await new RealtimeClient("APP", "T", g.fetcher)
      .pushTracks("S", "O", [])
      .catch((x) => x);
    expect(e2).toBeInstanceOf(RealtimeError);
    expect(e2.code).toBe("bad_sdp");
  });
});

describe("servidores ICE", () => {
  it("sem chave TURN: só o STUN do Cloudflare", async () => {
    expect(await iceServers(undefined, undefined)).toEqual([
      { urls: "stun:stun.cloudflare.com:3478" },
    ]);
  });

  it("com chave TURN: pede credenciais de 2 h", async () => {
    const f = fakeFetch([{ json: { iceServers: [{ urls: ["turn:x"], username: "u", credential: "c" }] } }]);
    const s = await iceServers("K", "TOKEN", f.fetcher);
    expect(s).toEqual([{ urls: ["turn:x"], username: "u", credential: "c" }]);
    expect(f.calls[0]).toMatchObject({
      url: "https://rtc.live.cloudflare.com/v1/turn/keys/K/credentials/generate-ice-servers",
      method: "POST",
      auth: "Bearer TOKEN",
      body: { ttl: 7200 },
    });
  });
});
