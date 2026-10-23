import { describe, expect, it } from "vitest";
import {
  BadCodeLimiter,
  formatRoomCode,
  generateRoomCode,
  normalizeRoomCode,
} from "../src/codes";

describe("códigos de sala", () => {
  it("código tem 6 caracteres do alfabeto", () => {
    for (let i = 0; i < 50; i++) {
      expect(generateRoomCode()).toMatch(/^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$/);
    }
  });

  it("normaliza entrada do usuário", () => {
    expect(normalizeRoomCode(" k7p-92q ")).toBe("K7P92Q");
    expect(normalizeRoomCode("K7P92")).toBeNull();
    expect(normalizeRoomCode("K7P-920")).toBeNull(); // 0 fora do alfabeto
    expect(formatRoomCode("K7P92Q")).toBe("K7P-92Q");
  });

  it("bloqueia após 5 erros em 1 min e libera depois", () => {
    const l = new BadCodeLimiter();
    for (let i = 0; i < 5; i++) l.register("a", 1000 + i);
    expect(l.isBlocked("a", 2000)).toBe(true);
    expect(l.isBlocked("a", 1004 + 60_001)).toBe(false);
    expect(l.isBlocked("b", 2000)).toBe(false);
  });

  it("erros antigos (mais de 1 min) não contam", () => {
    const l = new BadCodeLimiter();
    for (let i = 0; i < 4; i++) l.register("a", i);
    l.register("a", 70_000);
    expect(l.isBlocked("a", 70_001)).toBe(false);
  });
});
