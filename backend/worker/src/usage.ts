/** Contabilidade de consumo e níveis de limite (seção 5 da spec). Funções puras. */

export type BudgetConfig = {
  /** Orçamento do mês em GB de saída. Com R$ 0, é a franquia com folga. */
  budgetGb: number;
  warnPercents: number[];
  /** Acima disto a sessão ativa é encerrada (após aviso). */
  ceilingPercent: number;
  usdPerGb: number;
  /** Franquia gratuita do Realtime (SFU + TURN, compartilhada). */
  freeGb: number;
  /** Estimativa configurável; não é a cotação real. */
  brlPerUsd: number;
};

export const DEFAULT_BUDGET: BudgetConfig = {
  budgetGb: 900,
  warnPercents: [50, 75, 90, 100],
  ceilingPercent: 105,
  usdPerGb: 0.05,
  freeGb: 1000,
  brlPerUsd: 5.5,
};

const GB = 1e9;

/** Mês em UTC, o mesmo relógio das cotas do Cloudflare. */
export function monthKey(nowMs: number): string {
  const d = new Date(nowMs);
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
}

export function serverEstimateBytes(
  bitrateBps: number,
  viewers: number,
  ms: number,
): number {
  return (bitrateBps / 8) * viewers * (ms / 1000);
}

/** Vale a maior: um app que pare de relatar não esconde consumo. */
export function effectiveEgressBytes(reported: number, serverEstimate: number): number {
  return Math.max(reported, serverEstimate);
}

export function estimatedCostUsd(monthEgressBytes: number, c: BudgetConfig): number {
  return Math.max(0, monthEgressBytes / GB - c.freeGb) * c.usdPerGb;
}

export type LimitLevel = "normal" | "warn" | "blocked" | "ceiling";

export function limitLevel(monthEgressBytes: number, c: BudgetConfig): LimitLevel {
  const pct = (monthEgressBytes / GB / c.budgetGb) * 100;
  if (pct >= c.ceilingPercent) return "ceiling";
  if (pct >= 100) return "blocked";
  if (pct >= 90) return "warn";
  return "normal";
}

export function crossedWarnings(
  prevBytes: number,
  nextBytes: number,
  c: BudgetConfig,
): number[] {
  const pct = (b: number) => (b / GB / c.budgetGb) * 100;
  return c.warnPercents.filter((w) => pct(prevBytes) < w && pct(nextBytes) >= w);
}

/** Ritmo linear do mês até agora, levado ao fim do mês UTC. */
export function projectMonthBytes(monthBytesSoFar: number, nowMs: number): number {
  const d = new Date(nowMs);
  const start = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1);
  const end = Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 1);
  const elapsed = nowMs - start;
  if (elapsed <= 0) return monthBytesSoFar;
  return (monthBytesSoFar * (end - start)) / elapsed;
}
