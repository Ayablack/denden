import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

/** SFU de mentira para os testes de rota: responde às chamadas de saída. */
let sessions = 0;
async function fakeSfu(request: Request): Promise<Response> {
  const url = new URL(request.url);
  const json = (v: unknown) =>
    new Response(JSON.stringify(v), { headers: { "Content-Type": "application/json" } });
  if (url.hostname !== "rtc.live.cloudflare.com") return new Response("bloqueado", { status: 599 });
  if (url.pathname.endsWith("/sessions/new")) return json({ sessionId: `S${++sessions}` });
  if (url.pathname.endsWith("/tracks/new")) {
    const body = (await request.json()) as { tracks: Array<{ location: string }> };
    return body.tracks[0]?.location === "remote"
      ? json({ requiresImmediateRenegotiation: true, sessionDescription: { type: "offer", sdp: "OFERTA_SFU" } })
      : json({ sessionDescription: { type: "answer", sdp: "RESP_SFU" }, tracks: [] });
  }
  if (url.pathname.endsWith("/renegotiate") || url.pathname.endsWith("/tracks/close")) return json({});
  return new Response("?", { status: 404 });
}

export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: "./wrangler.jsonc" },
      miniflare: {
        bindings: {
          REALTIME_APP_ID: "APP",
          REALTIME_APP_TOKEN: "SEGREDO-DE-TESTE",
          // sha256("admin-teste")
          ADMIN_KEY_HASH: "b80e7c10361b38504ba8a1ff002813479eb270b4cc0a638a999033b41c281bd1",
        },
        outboundService: fakeSfu,
      },
    }),
  ],
});
