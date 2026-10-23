// Cria a chave pessoal de um amigo no Worker. Uso:
//   set DENDEN_ADMIN=<sua chave de administrador>
//   npm run criar-chave -- https://denden-worker.xxx.workers.dev "Nome do amigo"
// A chave aparece UMA vez: mande por mensagem privada só para essa pessoa.
const [url, name] = process.argv.slice(2);
const admin = process.env.DENDEN_ADMIN;
if (!url || !name || !admin) {
  console.error("Uso: DENDEN_ADMIN=<chave> npm run criar-chave -- <url do worker> <nome>");
  process.exit(1);
}
const res = await fetch(new URL("/admin/chaves", url), {
  method: "POST",
  headers: { "Content-Type": "application/json", "X-DenDen-Admin": admin },
  body: JSON.stringify({ name }),
});
const json = await res.json();
if (!res.ok) {
  console.error(`Erro ${res.status}: ${json.message ?? json.error}`);
  process.exit(1);
}
console.log(`Chave de ${name} (mande só para essa pessoa):\n  ${json.key}`);
console.log(`Identificador para revogar depois:\n  ${json.hash}`);
