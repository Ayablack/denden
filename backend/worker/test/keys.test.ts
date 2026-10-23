import { describe, expect, it } from "vitest";
import { generateKey, hashKey } from "../src/keys";

describe("chaves", () => {
  it("hash SHA-256 em hex, estável", async () => {
    expect(await hashKey("abc")).toBe(
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    );
  });

  it("chave nova: 32 bytes em base64url, sempre diferente", () => {
    const a = generateKey();
    expect(a).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(generateKey()).not.toBe(a);
  });
});
