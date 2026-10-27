/** SHA-256 em hex. O Worker guarda só o hash das chaves, nunca a chave. */
export async function hashKey(key: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(key),
  );
  return Array.from(new Uint8Array(digest), (b) =>
    b.toString(16).padStart(2, "0"),
  ).join("");
}

/** Compara hashes hex sem revelar em que posição eles diferem. */
export function sameHash(a: string, b: string): boolean {
  if (a.length !== b.length || !/^[0-9a-f]+$/i.test(a) || !/^[0-9a-f]+$/i.test(b)) {
    return false;
  }
  const bytes = (hash: string) =>
    new Uint8Array(hash.match(/../g)!.map((part) => Number.parseInt(part, 16)));
  return crypto.subtle.timingSafeEqual(bytes(a), bytes(b));
}

/** Chave pessoal nova: 32 bytes aleatórios em base64url, sem preenchimento. */
export function generateKey(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}
