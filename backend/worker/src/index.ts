import { hashKey } from "./keys";
import { iceServers } from "./realtime";
import type { CallResult } from "./state";

export { GroupState } from "./state";

const PROFILES = ["high", "medium", "economy"];

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });

const fail = (status: number, error: string, message: string) =>
  json(status, { error, message });

class BadRequest extends Error {}

function need<T>(ok: boolean, value: T, what: string): T {
  if (!ok) throw new BadRequest(what);
  return value;
}

async function body(req: Request): Promise<Record<string, unknown>> {
  try {
    const b = await req.json();
    return b && typeof b === "object" ? (b as Record<string, unknown>) : {};
  } catch {
    return {};
  }
}

const isTracks = (t: unknown) =>
  Array.isArray(t) &&
  t.length > 0 &&
  t.every((x) => x && typeof x.mid === "string" && typeof x.trackName === "string");

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    const parts = url.pathname.split("/").filter(Boolean);
    const key = req.headers.get("X-DenDen-Key") ?? "";
    const stub = env.GROUP.get(env.GROUP.idFromName("grupo"));
    const now = Date.now();

    const run = async (op: string, args: unknown[], extra?: Record<string, unknown>) => {
      const r = (await stub.call(op, args)) as CallResult;
      if (!r.ok) return fail(r.status, r.code, r.message);
      return json(200, { ...(r.value as object), ...extra });
    };

    try {
      // --- Administração (chave de administrador separada) ---
      if (parts[0] === "admin") {
        const admin = req.headers.get("X-DenDen-Admin");
        if (!admin || (await hashKey(admin)) !== env.ADMIN_KEY_HASH) {
          return fail(403, "nao_e_admin", "Só o administrador pode fazer isto.");
        }
        const b = req.method === "POST" ? await body(req) : {};
        if (parts[1] === "chaves" && parts.length === 2) {
          const name = need(typeof b.name === "string" && b.name.length > 0, b.name, "name");
          return run("addKey", [name]);
        }
        if (parts[1] === "chaves" && parts[3] === "revogar") return run("revokeKey", [parts[2]]);
        if (parts[1] === "config") return run("setConfig", [b]);
        if (parts[1] === "confirmado") {
          return run("setConfirmed", [
            need(typeof b.month === "string", b.month, "month"),
            typeof b.confirmedGb === "number" ? b.confirmedGb : undefined,
            typeof b.billedBrl === "number" ? b.billedBrl : undefined,
          ]);
        }
        if (parts[1] === "emergencia") {
          return run("setEmergency", [need(typeof b.on === "boolean", b.on, "on"), now]);
        }
        return fail(404, "rota_inexistente", "Rota não encontrada.");
      }

      if (!key) return fail(401, "chave_invalida", "Chave do grupo inválida.");

      if (parts[0] === "consumo" && req.method === "GET") return run("usage", [key, now]);

      if (parts[0] === "salas") {
        const code = parts[1];
        const action = parts[2];
        const ice = () => iceServers(env.TURN_KEY_ID, env.TURN_KEY_API_TOKEN);
        if (!code && req.method === "POST") {
          const b = await body(req);
          const profile = need(PROFILES.includes(b.profile as string), b.profile, "profile");
          const offerSdp = need(typeof b.offerSdp === "string", b.offerSdp, "offerSdp");
          const tracks = need(isTracks(b.tracks), b.tracks, "tracks");
          return run("createRoom", [key, { profile, offerSdp, tracks }, now], {
            iceServers: await ice(),
          });
        }
        if (code && !action && req.method === "GET") return run("roomState", [code]);
        if (code && req.method === "POST") {
          const b = await body(req);
          const ip = req.headers.get("CF-Connecting-IP") ?? "local";
          if (action === "entrar") {
            return run("joinRoom", [key, code, ip, now], { iceServers: await ice() });
          }
          if (action === "resposta") {
            return run("answer", [
              key,
              code,
              need(typeof b.viewerId === "string", b.viewerId, "viewerId"),
              need(typeof b.answerSdp === "string", b.answerSdp, "answerSdp"),
              now,
            ]);
          }
          if (action === "relatorio") {
            return run("report", [
              key,
              code,
              need(typeof b.who === "string", b.who, "who"),
              need(typeof b.bytes === "number" && b.bytes >= 0, b.bytes, "bytes"),
              now,
            ]);
          }
          if (action === "encerrar") return run("endRoom", [key, code, now]);
        }
      }
      return fail(404, "rota_inexistente", "Rota não encontrada.");
    } catch (e) {
      if (e instanceof BadRequest) return fail(400, "pedido_invalido", `Campo inválido: ${e.message}`);
      return fail(500, "erro_interno", "Erro interno do DenDen.");
    }
  },
} satisfies ExportedHandler<Env>;
