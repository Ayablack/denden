/** Cliente da API HTTPS do Cloudflare Realtime SFU. Só o Worker tem o segredo. */

const API = "https://rtc.live.cloudflare.com/v1";

export class RealtimeError extends Error {
  constructor(
    readonly status: number,
    readonly code: string | undefined,
    description: string,
  ) {
    // Nunca inclui cabeçalhos nem o segredo.
    super(`Realtime ${status}${code ? ` ${code}` : ""}: ${description}`);
    this.name = "RealtimeError";
  }
}

export type LocalTrack = { mid: string; trackName: string };

/** O que o grupo precisa do SFU; o teste usa uma versão falsa. */
export interface RealtimePort {
  newSession(): Promise<string>;
  pushTracks(
    sessionId: string,
    offerSdp: string,
    tracks: LocalTrack[],
  ): Promise<{ answerSdp: string }>;
  pullTracks(
    sessionId: string,
    remoteSessionId: string,
    trackNames: string[],
  ): Promise<{ offerSdp?: string; requiresImmediateRenegotiation: boolean }>;
  renegotiate(sessionId: string, answerSdp: string): Promise<void>;
  closeTracks(sessionId: string, mids: string[]): Promise<void>;
}

type Json = Record<string, unknown>;

export class RealtimeClient implements RealtimePort {
  constructor(
    private readonly appId: string,
    private readonly token: string,
    private readonly fetcher: typeof fetch = (i, init) => fetch(i, init),
  ) {}

  private async call(method: string, path: string, body?: Json): Promise<Json> {
    const res = await this.fetcher(`${API}/apps/${this.appId}${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${this.token}`,
        "Content-Type": "application/json",
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    let json: Json = {};
    try {
      json = (await res.json()) as Json;
    } catch {
      // Corpo vazio ou não-JSON: decide pelo status.
    }
    const code = json.errorCode as string | undefined;
    if (!res.ok || code) {
      throw new RealtimeError(
        res.status,
        code,
        (json.errorDescription as string | undefined) ?? res.statusText,
      );
    }
    return json;
  }

  async newSession(): Promise<string> {
    const json = await this.call("POST", "/sessions/new");
    return json.sessionId as string;
  }

  async pushTracks(sessionId: string, offerSdp: string, tracks: LocalTrack[]) {
    const json = await this.call("POST", `/sessions/${sessionId}/tracks/new`, {
      sessionDescription: { type: "offer", sdp: offerSdp },
      tracks: tracks.map((t) => ({ location: "local", ...t })),
    });
    const sd = json.sessionDescription as { sdp: string } | undefined;
    if (!sd) throw new RealtimeError(200, "sem_resposta", "SFU não devolveu SDP");
    return { answerSdp: sd.sdp };
  }

  async pullTracks(sessionId: string, remoteSessionId: string, trackNames: string[]) {
    const json = await this.call("POST", `/sessions/${sessionId}/tracks/new`, {
      tracks: trackNames.map((trackName) => ({
        location: "remote",
        sessionId: remoteSessionId,
        trackName,
      })),
    });
    const sd = json.sessionDescription as { sdp: string } | undefined;
    return {
      offerSdp: sd?.sdp,
      requiresImmediateRenegotiation: json.requiresImmediateRenegotiation === true,
    };
  }

  async renegotiate(sessionId: string, answerSdp: string): Promise<void> {
    await this.call("PUT", `/sessions/${sessionId}/renegotiate`, {
      sessionDescription: { type: "answer", sdp: answerSdp },
    });
  }

  async closeTracks(sessionId: string, mids: string[]): Promise<void> {
    await this.call("PUT", `/sessions/${sessionId}/tracks/close`, {
      tracks: mids.map((mid) => ({ mid })),
      force: true,
    });
  }
}

export type IceServer = { urls: string | string[]; username?: string; credential?: string };

/** STUN sempre; TURN só se houver chave (mesma franquia gratuita do SFU). */
export async function iceServers(
  turnKeyId: string | undefined,
  turnApiToken: string | undefined,
  fetcher: typeof fetch = (i, init) => fetch(i, init),
  ttlSec = 7200,
): Promise<IceServer[]> {
  const stun: IceServer[] = [{ urls: "stun:stun.cloudflare.com:3478" }];
  if (!turnKeyId || !turnApiToken) return stun;
  const res = await fetcher(
    `${API}/turn/keys/${turnKeyId}/credentials/generate-ice-servers`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${turnApiToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ ttl: ttlSec }),
    },
  );
  if (!res.ok) throw new RealtimeError(res.status, "turn", "falha ao gerar TURN");
  const json = (await res.json()) as { iceServers: IceServer[] };
  return json.iceServers;
}
