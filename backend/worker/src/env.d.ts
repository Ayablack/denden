// Segredos do Worker (só via `wrangler secret put`). TURN é opcional.
// Funde com o `Env` global gerado por `wrangler types`.
interface Env {
  REALTIME_APP_ID: string;
  REALTIME_APP_TOKEN: string;
  ADMIN_KEY_HASH: string;
  TURN_KEY_ID?: string;
  TURN_KEY_API_TOKEN?: string;
}
