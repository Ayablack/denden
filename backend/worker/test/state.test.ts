import { describe, expect, it, vi } from "vitest";
import { GroupState } from "../src/state";

describe("porta RPC do grupo", () => {
  it("recusa métodos internos fora da lista de operações", async () => {
    const load = vi.fn();
    const result = await GroupState.prototype.call.call({ group: { load } }, "load", []);
    expect(result).toMatchObject({ ok: false, status: 400, code: "operacao_invalida" });
    expect(load).not.toHaveBeenCalled();
  });
});
