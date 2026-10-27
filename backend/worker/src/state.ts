import { DurableObject } from "cloudflare:workers";
import { Group, GroupError, type Store } from "./group";
import { RealtimeClient } from "./realtime";

export type CallResult =
  | { ok: true; value: unknown }
  | { ok: false; status: number; code: string; message: string };

const TICK_MS = 10_000;
const OPERATIONS = new Set([
  "addKey",
  "listKeys",
  "revokeKey",
  "checkKey",
  "createRoom",
  "joinRoom",
  "answer",
  "report",
  "endRoom",
  "roomState",
  "usage",
  "adminUsage",
  "setConfig",
  "setConfirmed",
  "setEmergency",
]);

/** Uma instância para o grupo inteiro (`idFromName("grupo")`), backend SQLite. */
export class GroupState extends DurableObject<Env> {
  private group: Group;

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    const store: Store = {
      get: (k) => ctx.storage.get(k),
      put: (k, v) => ctx.storage.put(k, v),
    };
    this.group = new Group(
      store,
      new RealtimeClient(env.REALTIME_APP_ID, env.REALTIME_APP_TOKEN),
      { adminKeyHash: env.ADMIN_KEY_HASH },
    );
  }

  /**
   * Uma porta de entrada por RPC: erros do grupo voltam como dados, porque
   * campos próprios de uma exceção se perdem no caminho do RPC.
   */
  async call(op: string, args: unknown[]): Promise<CallResult> {
    if (!OPERATIONS.has(op)) {
      return {
        ok: false,
        status: 400,
        code: "operacao_invalida",
        message: "Operação não permitida.",
      };
    }
    const fn = (this.group as unknown as Record<string, unknown>)[op];
    if (typeof fn !== "function") {
      return { ok: false, status: 400, code: "operacao_invalida", message: "Operação não permitida." };
    }
    try {
      const value = await (fn as (...a: unknown[]) => Promise<unknown>).apply(this.group, args);
      if (op === "createRoom" || op === "report" || op === "joinRoom") await this.ensureAlarm();
      return { ok: true, value: value ?? {} };
    } catch (e) {
      if (e instanceof GroupError) {
        return { ok: false, status: e.status, code: e.code, message: e.message };
      }
      throw e;
    }
  }

  private async ensureAlarm(): Promise<void> {
    if ((await this.ctx.storage.getAlarm()) === null) {
      await this.ctx.storage.setAlarm(Date.now() + TICK_MS);
    }
  }

  async alarm(): Promise<void> {
    const { liveRooms } = await this.group.tick(Date.now());
    if (liveRooms > 0) await this.ctx.storage.setAlarm(Date.now() + TICK_MS);
  }
}
