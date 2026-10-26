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
    // Primeiro milissegundo do mês
    expect(monthKey(Date.UTC(2027, 0, 1, 0, 0, 0, 1))).toBe("2027-01");
    // Virada de mês bissexto
    expect(monthKey(Date.UTC(2024, 1, 29, 23, 59, 59, 999))).toBe("2024-02");
    expect(monthKey(Date.UTC(2024, 2, 1, 0, 0, 0, 0))).toBe("2024-03");
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
    expect(estimatedCostUsd(1000 * GB, DEFAULT_BUDGET)).toBe(0); // exatamente na franquia
    expect(estimatedCostUsd(1200 * GB, DEFAULT_BUDGET)).toBeCloseTo(10, 5); // acima da franquia
  });

  it("níveis com orçamento de 900 GB", () => {
    expect(limitLevel(800 * GB, DEFAULT_BUDGET)).toBe("normal");
    expect(limitLevel(820 * GB, DEFAULT_BUDGET)).toBe("warn");
    expect(limitLevel(810 * GB, DEFAULT_BUDGET)).toBe("warn"); // exactly 90% (900 * 0.9 = 810)
    expect(limitLevel(900 * GB, DEFAULT_BUDGET)).toBe("blocked"); // exactly 100%
    expect(limitLevel(945 * GB, DEFAULT_BUDGET)).toBe("ceiling"); // exactly 105% (900 * 1.05 = 945)
  });

  it("avisos atravessados", () => {
    expect(crossedWarnings(440 * GB, 700 * GB, DEFAULT_BUDGET)).toEqual([50, 75]);
    expect(crossedWarnings(700 * GB, 701 * GB, DEFAULT_BUDGET)).toEqual([]);
    expect(crossedWarnings(0 * GB, 950 * GB, DEFAULT_BUDGET)).toEqual([50, 75, 90, 100]); // pulando vários avisos
  });

  it("projeção linear até o fim do mês UTC", () => {
    // 10 de 31 dias de outubro passados com 300 GB → 930 GB no mês.
    const now = Date.UTC(2026, 9, 11, 0, 0);
    expect(projectMonthBytes(300 * GB, now) / GB).toBeCloseTo(930, 0);

    // primeiro milissegundo do mes
    const firstMs = Date.UTC(2026, 9, 1, 0, 0, 0, 1);
    expect(projectMonthBytes(10, firstMs)).toBeCloseTo(26784000000, -5);

    // ano bissexto (fevereiro de 2024 - 29 dias)
    // 14.5 dias de 29 dias com 50 GB -> ~100 GB no mês
    const leapNow = Date.UTC(2024, 1, 15, 12, 0);
    expect(projectMonthBytes(50 * GB, leapNow) / GB).toBeCloseTo(100, 0);
  });

  it("padrões da spec", () => {
    expect(DEFAULT_BUDGET).toEqual({
      budgetGb: 900,
      warnPercents: [50, 75, 90, 100],
      ceilingPercent: 105,
      usdPerGb: 0.05,
      freeGb: 1000,
      brlPerUsd: 5.5,
      maxSessionHours: 6,
    });
  });
});
