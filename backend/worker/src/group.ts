/**
 * Estado do grupo: chaves, salas, espectadores, consumo e limites.
 * Sem I/O próprio: recebe o armazenamento e o SFU de fora, e o relógio em
 * cada chamada, para ser testado sem rede.
 */
import { BadCodeLimiter, generateRoomCode, normalizeRoomCode } from "./codes";
import { generateKey, hashKey } from "./keys";
import { RealtimeError, type LocalTrack, type RealtimePort } from "./realtime";
import {
  DEFAULT_BUDGET,
  type BudgetConfig,
  type LimitLevel,
  crossedWarnings,
  effectiveEgressBytes,
  estimatedCostUsd,
  limitLevel,
  monthKey,
  projectMonthBytes,
} from "./usage";

export interface Store {
  get<T>(key: string): Promise<T | undefined>;
  put<T>(key: string, value: T): Promise<void>;
}

export class MemoryStore implements Store {
  private data = new Map<string, unknown>();
  async get<T>(key: string) {
    const v = this.data.get(key);
    return v === undefined ? undefined : (structuredClone(v) as T);
  }
  async put<T>(key: string, value: T) {
    this.data.set(key, structuredClone(value));
  }
}

export class GroupError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = "GroupError";
  }
}

export type Profile = "high" | "medium" | "economy";
export const PROFILE_BPS: Record<Profile, number> = {
  high: 6_000_000,
  medium: 3_500_000,
  economy: 2_000_000,
};

export const MAX_VIEWERS = 5;
export const INACTIVE_MS = 30_000;
export const CEILING_GRACE_MS = 60_000;
/** Conferir no SFU se as trilhas de quem transmite estão ativas. */
export const SFU_CHECK_MS = 60_000;
export const SFU_MAX_MISSES = 2;
const HOUR_MS = 3_600_000;
export const NOTICE =
  "O bloqueio do DenDen não é um limite garantido de faturamento do Cloudflare.";

type Viewer = {
  id: string;
  sessionId: string;
  lastReportAt: number;
  receivedBytes: number;
};

type Room = {
  code: string;
  publisherHash: string;
  publisherSession: string;
  tracks: LocalTrack[];
  profile: Profile;
  startedAt: number;
  lastPublisherReportAt: number;
  publisherSentBytes: number;
  egressBytes: number;
  viewers: Viewer[];
  ceilingSince?: number;
  lastSfuCheckAt?: number;
  sfuMisses?: number;
  endedAt?: number;
  endReason?: string;
};

type MonthUsage = {
  reportedEgressBytes: number;
  serverEgressBytes: number;
  confirmedGb?: number;
  billedBrl?: number;
};

type HistoryEntry = {
  code: string;
  startedAt: number;
  endedAt: number;
  reason: string;
  egressBytes: number;
};

type State = {
  keys: Record<string, { name: string; revoked: boolean }>;
  rooms: Record<string, Room>;
  months: Record<string, MonthUsage>;
  config: BudgetConfig;
  emergency: boolean;
  history: HistoryEntry[];
};

const emptyState = (): State => ({
  keys: {},
  rooms: {},
  months: {},
  config: { ...DEFAULT_BUDGET },
  emergency: false,
  history: [],
});

export type ReportResult = {
  level: LimitLevel;
  profile: Profile;
  warnings: number[];
  endsAtMs?: number;
  /** Fim pela duração máxima; o app avisa 5 min antes. */
  sessionEndsAtMs: number;
  roomEgressBytes: number;
  monthEgressBytes: number;
};

export class Group {
  private limiter = new BadCodeLimiter();

  constructor(
    private readonly store: Store,
    private readonly rt: RealtimePort,
    private readonly opts: { adminKeyHash?: string },
  ) {}

  private async load(): Promise<State> {
    const s = (await this.store.get<State>("state")) ?? emptyState();
    // Estado gravado por uma versão anterior: campos novos ganham o padrão.
    s.config = { ...DEFAULT_BUDGET, ...s.config };
    return s;
  }

  private save(s: State): Promise<void> {
    return this.store.put("state", s);
  }

  private async keyHash(s: State, key: string): Promise<string> {
    const h = await hashKey(key);
    const k = s.keys[h];
    if (!k || k.revoked) {
      throw new GroupError(401, "chave_invalida", "Chave do grupo inválida.");
    }
    return h;
  }

  private month(s: State, now: number): MonthUsage {
    const k = monthKey(now);
    return (s.months[k] ??= { reportedEgressBytes: 0, serverEgressBytes: 0 });
  }

  private effective(m: MonthUsage): number {
    return effectiveEgressBytes(m.reportedEgressBytes, m.serverEgressBytes);
  }

  private liveRoom(s: State, rawCode: string): Room {
    const code = normalizeRoomCode(rawCode);
    const room = code ? s.rooms[code] : undefined;
    if (!room || room.endedAt !== undefined) {
      throw new GroupError(404, "sala_inexistente", "Sala não encontrada ou encerrada.");
    }
    return room;
  }

  private async provider<T>(op: () => Promise<T>): Promise<T> {
    try {
      return await op();
    } catch (e) {
      if (e instanceof RealtimeError) {
        throw new GroupError(502, "provedor", "O servidor de mídia não respondeu.");
      }
      throw e;
    }
  }

  // --- Chaves -------------------------------------------------------------

  /** Devolve a chave uma única vez; o grupo guarda só o hash. */
  async addKey(name: string): Promise<{ key: string; hash: string }> {
    const s = await this.load();
    const key = generateKey();
    const hash = await hashKey(key);
    s.keys[hash] = { name, revoked: false };
    await this.save(s);
    return { key, hash };
  }

  /** Só confere a chave (ex.: antes de entregar servidores ICE). */
  async checkKey(key: string): Promise<void> {
    await this.keyHash(await this.load(), key);
  }

  async revokeKey(hash: string): Promise<void> {
    const s = await this.load();
    if (!Object.hasOwn(s.keys, hash)) {
      throw new GroupError(404, "chave_inexistente", "Chave não encontrada.");
    }
    s.keys[hash].revoked = true;
    await this.save(s);
  }

  // --- Salas --------------------------------------------------------------

  async createRoom(
    key: string,
    req: { profile: Profile; offerSdp: string; tracks: LocalTrack[] },
    now: number,
  ): Promise<{ code: string; sessionId: string; answerSdp: string }> {
    const s = await this.load();
    const hash = await this.keyHash(s, key);
    if (s.emergency) {
      throw new GroupError(503, "emergencia", "Transmissões desligadas pelo administrador.");
    }
    const level = limitLevel(this.effective(this.month(s, now)), s.config);
    if (level === "blocked" || level === "ceiling") {
      throw new GroupError(
        403,
        "orcamento",
        "Limite do mês atingido. Novas transmissões estão bloqueadas.",
      );
    }
    const tracks = req.tracks.map(({ mid, trackName }) => ({ mid, trackName }));
    const sessionId = await this.provider(() => this.rt.newSession());
    const { answerSdp } = await this.provider(() =>
      this.rt.pushTracks(sessionId, req.offerSdp, tracks),
    );
    let code = generateRoomCode();
    while (s.rooms[code]) code = generateRoomCode();
    s.rooms[code] = {
      code,
      publisherHash: hash,
      publisherSession: sessionId,
      tracks,
      profile: req.profile,
      startedAt: now,
      lastPublisherReportAt: now,
      publisherSentBytes: 0,
      egressBytes: 0,
      viewers: [],
    };
    await this.save(s);
    return { code, sessionId, answerSdp };
  }

  async joinRoom(
    key: string,
    rawCode: string,
    who: string,
    now: number,
  ): Promise<{ viewerId: string; sessionId: string; offerSdp: string }> {
    const s = await this.load();
    const hash = await this.keyHash(s, key);
    const attempt = `${hash}:${who}`;
    if (this.limiter.isBlocked(attempt, now)) {
      throw new GroupError(429, "bloqueado", "Muitas tentativas. Espere 1 minuto.");
    }
    let room: Room;
    try {
      room = this.liveRoom(s, rawCode);
    } catch (e) {
      this.limiter.register(attempt, now);
      throw e;
    }
    if (room.viewers.length >= MAX_VIEWERS) {
      throw new GroupError(409, "sala_cheia", `A sala já tem ${MAX_VIEWERS} espectadores.`);
    }
    const sessionId = await this.provider(() => this.rt.newSession());
    const pulled = await this.provider(() =>
      this.rt.pullTracks(
        sessionId,
        room.publisherSession,
        room.tracks.map((t) => t.trackName),
      ),
    );
    if (!pulled.offerSdp) {
      throw new GroupError(502, "provedor", "O servidor de mídia não enviou a oferta.");
    }
    const viewerId = crypto.randomUUID();
    room.viewers.push({ id: viewerId, sessionId, lastReportAt: now, receivedBytes: 0 });
    await this.save(s);
    return { viewerId, sessionId, offerSdp: pulled.offerSdp };
  }

  async answer(
    key: string,
    rawCode: string,
    viewerId: string,
    answerSdp: string,
    now: number,
  ): Promise<void> {
    const s = await this.load();
    await this.keyHash(s, key);
    const viewer = this.liveRoom(s, rawCode).viewers.find((v) => v.id === viewerId);
    if (!viewer) throw new GroupError(404, "espectador_inexistente", "Espectador não encontrado.");
    await this.provider(() => this.rt.renegotiate(viewer.sessionId, answerSdp));
    viewer.lastReportAt = now;
    await this.save(s);
  }

  /** Relatórios trazem bytes cumulativos; aqui viram diferenças. */
  async report(
    key: string,
    rawCode: string,
    who: "publisher" | string,
    cumulativeBytes: number,
    now: number,
    newProfile?: Profile,
  ): Promise<ReportResult> {
    const s = await this.load();
    const hash = await this.keyHash(s, key);
    const room = this.liveRoom(s, rawCode);
    const m = this.month(s, now);
    const before = this.effective(m);

    if (who === "publisher") {
      if (room.publisherHash !== hash) {
        throw new GroupError(403, "nao_e_o_transmissor", "Só quem transmite relata como transmissor.");
      }
      const dt = Math.max(0, now - room.lastPublisherReportAt);
      m.serverEgressBytes +=
        (PROFILE_BPS[room.profile] / 8) * room.viewers.length * (dt / 1000);

      if (newProfile) {
        room.profile = newProfile;
      }

      room.publisherSentBytes = cumulativeBytes;
      room.lastPublisherReportAt = now;
    } else {
      const v = room.viewers.find((x) => x.id === who);
      if (!v) throw new GroupError(404, "espectador_inexistente", "Espectador não encontrado.");
      // Contador zerado (reconexão) conta tudo de novo como novo tráfego.
      const delta =
        cumulativeBytes >= v.receivedBytes ? cumulativeBytes - v.receivedBytes : cumulativeBytes;
      v.receivedBytes = cumulativeBytes;
      v.lastReportAt = now;
      m.reportedEgressBytes += delta;
      room.egressBytes += delta;
    }

    const after = this.effective(m);
    const level = limitLevel(after, s.config);
    if (level === "ceiling") room.ceilingSince ??= now;
    if (room.ceilingSince !== undefined && now >= room.ceilingSince + CEILING_GRACE_MS) {
      await this.end(s, room, "teto", now);
    }
    const sessionEndsAtMs = room.startedAt + s.config.maxSessionHours * HOUR_MS;
    if (now >= sessionEndsAtMs) await this.end(s, room, "duracao_maxima", now);
    await this.save(s);
    return {
      sessionEndsAtMs,
      level,
      profile: level === "blocked" || level === "ceiling" ? "economy" : room.profile,
      warnings: crossedWarnings(before, after, s.config),
      endsAtMs:
        room.ceilingSince === undefined ? undefined : room.ceilingSince + CEILING_GRACE_MS,
      roomEgressBytes: room.egressBytes,
      monthEgressBytes: after,
    };
  }

  async endRoom(key: string, rawCode: string, now: number): Promise<void> {
    const s = await this.load();
    const hash = await this.keyHash(s, key);
    const room = this.liveRoom(s, rawCode);
    if (room.publisherHash !== hash) {
      throw new GroupError(403, "nao_e_o_transmissor", "Só quem transmite encerra a sala.");
    }
    await this.end(s, room, "parado", now);
    await this.save(s);
  }

  async roomState(rawCode: string): Promise<{ state: "live" | "ended"; viewers: number }> {
    const s = await this.load();
    const code = normalizeRoomCode(rawCode);
    const room = code ? s.rooms[code] : undefined;
    if (!room) throw new GroupError(404, "sala_inexistente", "Sala não encontrada.");
    return {
      state: room.endedAt === undefined ? "live" : "ended",
      viewers: room.endedAt === undefined ? room.viewers.length : 0,
    };
  }

  private async end(s: State, room: Room, reason: string, now: number): Promise<void> {
    if (room.endedAt !== undefined) return;
    room.endedAt = now;
    room.endReason = reason;
    try {
      await this.rt.closeTracks(room.publisherSession, room.tracks.map((t) => t.mid));
    } catch {
      // Sem pacotes, o SFU descarta a trilha sozinho em 30 s.
    }
    room.viewers = [];
    s.history.unshift({
      code: room.code,
      startedAt: room.startedAt,
      endedAt: now,
      reason,
      egressBytes: room.egressBytes,
    });
    s.history = s.history.slice(0, 50);
  }

  /** Chamado pelo alarme: quedas, espectadores sumidos, teto e limpeza. */
  async tick(now: number): Promise<{ liveRooms: number }> {
    const s = await this.load();
    let live = 0;
    for (const room of Object.values(s.rooms)) {
      if (room.endedAt !== undefined) {
        if (now - room.endedAt > 3_600_000) delete s.rooms[room.code];
        continue;
      }
      if (now - room.lastPublisherReportAt > INACTIVE_MS) {
        await this.end(s, room, "queda", now);
        continue;
      }
      if (room.ceilingSince !== undefined && now >= room.ceilingSince + CEILING_GRACE_MS) {
        await this.end(s, room, "teto", now);
        continue;
      }
      if (now >= room.startedAt + s.config.maxSessionHours * HOUR_MS) {
        await this.end(s, room, "duracao_maxima", now);
        continue;
      }
      if (await this.sfuSilent(room, now)) {
        await this.end(s, room, "sem_sinal", now);
        continue;
      }
      room.viewers = room.viewers.filter((v) => now - v.lastReportAt <= INACTIVE_MS);
      live++;
    }
    await this.save(s);
    return { liveRooms: live };
  }

  /**
   * Confere no SFU, a cada [SFU_CHECK_MS], se há trilha ativa de quem
   * transmite. `true` depois de [SFU_MAX_MISSES] faltas seguidas. Erro da API
   * não conta: o SFU pode estar só lento.
   */
  private async sfuSilent(room: Room, now: number): Promise<boolean> {
    if (now - (room.lastSfuCheckAt ?? room.startedAt) < SFU_CHECK_MS) return false;
    room.lastSfuCheckAt = now;
    try {
      const { tracks } = await this.rt.getSession(room.publisherSession);
      const active = tracks.some((t) => t.status === "active");
      room.sfuMisses = active ? 0 : (room.sfuMisses ?? 0) + 1;
    } catch (e) {
      if (!(e instanceof RealtimeError)) throw e;
    }
    return (room.sfuMisses ?? 0) >= SFU_MAX_MISSES;
  }

  // --- Consumo e administração ---------------------------------------------

  async usage(key: string, now: number) {
    const s = await this.load();
    await this.keyHash(s, key);
    return this.panel(s, now);
  }

  /** O mesmo painel, para a tela de administração. */
  async adminUsage(now: number) {
    return this.panel(await this.load(), now);
  }

  async listKeys(): Promise<Array<{ name: string; hash: string; revoked: boolean }>> {
    const s = await this.load();
    return Object.entries(s.keys).map(([hash, k]) => ({
      name: k.name,
      hash,
      revoked: k.revoked,
    }));
  }

  private panel(s: State, now: number) {
    const month = monthKey(now);
    const m = this.month(s, now);
    const effective = this.effective(m);
    const usd = estimatedCostUsd(effective, s.config);
    return {
      month,
      reportedEgressBytes: m.reportedEgressBytes,
      serverEgressBytes: m.serverEgressBytes,
      effectiveEgressBytes: effective,
      confirmedGb: m.confirmedGb ?? null,
      billedBrl: m.billedBrl ?? null,
      estimatedCostUsd: usd,
      estimatedCostBrl: usd * s.config.brlPerUsd,
      percentOfBudget: (effective / 1e9 / s.config.budgetGb) * 100,
      warnings: s.config.warnPercents.map((percent) => ({
        percent,
        reached: (effective / 1e9 / s.config.budgetGb) * 100 >= percent,
      })),
      level: limitLevel(effective, s.config),
      projectionBytes: projectMonthBytes(effective, now),
      config: s.config,
      emergency: s.emergency,
      rooms: Object.values(s.rooms)
        .filter((r) => r.endedAt === undefined)
        .map((r) => ({
          code: r.code,
          startedAt: r.startedAt,
          publisherSentBytes: r.publisherSentBytes,
          egressBytes: r.egressBytes,
          viewers: r.viewers.map((v) => ({ id: v.id, receivedBytes: v.receivedBytes })),
        })),
      history: s.history,
      notice: NOTICE,
    };
  }

  async setConfig(partial: Partial<BudgetConfig>): Promise<BudgetConfig> {
    const s = await this.load();
    const c = { ...s.config, ...partial };
    const positive = (n: unknown) => typeof n === "number" && Number.isFinite(n) && n > 0;
    const bad =
      !positive(c.budgetGb) ||
      !positive(c.usdPerGb) ||
      !positive(c.brlPerUsd) ||
      !(typeof c.freeGb === "number" && Number.isFinite(c.freeGb) && c.freeGb >= 0) ||
      !(typeof c.ceilingPercent === "number" && c.ceilingPercent >= 100 && c.ceilingPercent <= 200) ||
      !(typeof c.maxSessionHours === "number" && c.maxSessionHours >= 0.5 && c.maxSessionHours <= 24) ||
      !Array.isArray(c.warnPercents) ||
      c.warnPercents.some((w) => typeof w !== "number" || !(w > 0 && w <= 100));
    if (bad) {
      throw new GroupError(400, "config_invalida", "Limites inválidos.");
    }
    c.warnPercents = [...new Set(c.warnPercents)].sort((a, b) => a - b);
    s.config = c;
    await this.save(s);
    return s.config;
  }

  async setConfirmed(month: string, confirmedGb?: number, billedBrl?: number): Promise<void> {
    const s = await this.load();
    const m = (s.months[month] ??= { reportedEgressBytes: 0, serverEgressBytes: 0 });
    if (confirmedGb !== undefined) m.confirmedGb = confirmedGb;
    if (billedBrl !== undefined) m.billedBrl = billedBrl;
    await this.save(s);
  }

  async setEmergency(on: boolean, now: number): Promise<void> {
    const s = await this.load();
    s.emergency = on;
    if (on) {
      for (const room of Object.values(s.rooms)) await this.end(s, room, "emergencia", now);
    }
    await this.save(s);
  }
}
