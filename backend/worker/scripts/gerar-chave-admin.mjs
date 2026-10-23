// Gera a chave de administrador NO SEU PC. Nada sai daqui.
// - A CHAVE fica só com você (guarde num gerenciador de senhas).
// - O HASH vai para o Worker: `npx wrangler secret put ADMIN_KEY_HASH`.
import { webcrypto as crypto } from "node:crypto";

const bytes = crypto.getRandomValues(new Uint8Array(32));
const key = Buffer.from(bytes).toString("base64url");
const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(key));
const hash = Buffer.from(digest).toString("hex");
console.log(`Chave de administrador (guarde, não compartilhe):\n  ${key}\n`);
console.log(`Hash (vai para ADMIN_KEY_HASH):\n  ${hash}`);
