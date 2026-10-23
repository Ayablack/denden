import { DurableObject } from "cloudflare:workers";

export class GroupState extends DurableObject {}

export default {
  async fetch(): Promise<Response> {
    return new Response("não encontrado", { status: 404 });
  },
} satisfies ExportedHandler<Env>;
