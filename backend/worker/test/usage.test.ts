import { describe, expect, it } from "vitest";
import {
  DEFAULT_BUDGET,
  crossedWarnings,
  effectiveEgressBytes,
  estimatedCostUsd,
  limitLevel,
  monthKey,
  projectMonthBytes,
  serverEstimateBytes,
} from "../src/usage";

const GB = 1e9;

describe("consumo e limites", () => {
  it("mês vira em UTC", () => {
    expect(monthKey(Date.UTC(2026, 9, 31, 23, 59))).toBe("2026-10");
    expect(monthKey(Date.UTC(2026, 10, 1, 0, 0))).toBe("2026-11");
  });

  it("estimativa do servidor: 6 Mbps × 3 espectadores × 1 h ≈ 8,1 GB", () => {
    expect(serverEstimateBytes(6_000_000, 3, 3_600_000) / GB).toBeCloseTo(8.1, 1);
  });

  it("vale a maior estimativa", () => {
    expect(effectiveEgressBytes(5 * GB, 8 * GB)).toBe(8 * GB);
    expect(effectiveEgressBytes(9 * GB, 8 * GB)).toBe(9 * GB);
  });

  it("custo só acima da franquia", () => {
    expect(estimatedCostUsd(900 * GB, DEFAULT_BUDGET)).toBe(0);
    expect(estimatedCostUsd(1200 * GB, DEFAULT_BUDGET)).toBeCloseTo(10, 5);
  });

  it("níveis com orçamento de 900 GB", () => {
    expect(limitLevel(800 * GB, DEFAULT_BUDGET)).toBe("normal");
    expect(limitLevel(820 * GB, DEFAULT_BUDGET)).toBe("warn");
    expect(limitLevel(900 * GB, DEFAULT_BUDGET)).toBe("blocked");
    expect(limitLevel(945 * GB, DEFAULT_BUDGET)).toBe("ceiling");
  });

  it("avisos atravessados", () => {
    expect(crossedWarnings(440 * GB, 700 * GB, DEFAULT_BUDGET)).toEqual([50, 75]);
    expect(crossedWarnings(700 * GB, 701 * GB, DEFAULT_BUDGET)).toEqual([]);
  });

  it("projeção linear até o fim do mês UTC", () => {
    // 10 de 31 dias de outubro passados com 300 GB → 930 GB no mês.
    const now = Date.UTC(2026, 9, 11, 0, 0);
    expect(projectMonthBytes(300 * GB, now) / GB).toBeCloseTo(930, 0);
  });

  it("padrões da spec", () => {
    expect(DEFAULT_BUDGET).toEqual({
      budgetGb: 900,
      warnPercents: [50, 75, 90, 100],
      ceilingPercent: 105,
      usdPerGb: 0.05,
      freeGb: 1000,
      brlPerUsd: 5.5,
    });
  });
});
