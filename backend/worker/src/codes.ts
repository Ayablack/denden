/** Mesmo alfabeto do AppMusica: sem 0/O, 1/I/L, para ditar sem erro. */
const ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";
const LENGTH = 6;

export function generateRoomCode(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(LENGTH));
  // 256 não é múltiplo de 31; o viés (≤ 1%) não importa para um código de sala.
  return Array.from(bytes, (b) => ALPHABET[b % ALPHABET.length]).join("");
}

/** "K7P92Q" → "K7P-92Q", como aparece na tela. */
export function formatRoomCode(code: string): string {
  return `${code.slice(0, 3)}-${code.slice(3)}`;
}

/** Aceita minúsculas, espaços e hífen. `null` se não for um código válido. */
export function normalizeRoomCode(input: string): string | null {
  const c = input.toUpperCase().replace(/[\s-]/g, "");
  if (c.length !== LENGTH) return null;
  for (const ch of c) if (!ALPHABET.includes(ch)) return null;
  return c;
}

/** Porta de `_registerBadCode` do AppMusica: 5 erros em 1 min bloqueiam 1 min. */
export class BadCodeLimiter {
  private attempts = new Map<string, number[]>();
  private blockedUntil = new Map<string, number>();

  constructor(
    private readonly max = 5,
    private readonly windowMs = 60_000,
  ) {}

  register(who: string, now: number): void {
    const recent = (this.attempts.get(who) ?? []).filter(
      (t) => now - t <= this.windowMs,
    );
    recent.push(now);
    if (recent.length >= this.max) {
      this.blockedUntil.set(who, now + this.windowMs);
      this.attempts.delete(who);
    } else {
      this.attempts.set(who, recent);
    }
  }

  isBlocked(who: string, now: number): boolean {
    const until = this.blockedUntil.get(who);
    if (until === undefined) return false;
    if (now > until) {
      this.blockedUntil.delete(who);
      return false;
    }
    return true;
  }
}
