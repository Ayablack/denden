import 'dart:io';

/// Nomes do executável do Discord (normal, PTB e Canary).
const discordExeNames = {'discord.exe', 'discordptb.exe', 'discordcanary.exe'};

bool isDiscord(String exeName) =>
    discordExeNames.contains(exeName.trim().toLowerCase());

/// Um processo do Windows: nome, PID e PID do pai.
typedef ProcessEntry = ({String name, int pid, int parentPid});

/// O Discord roda em vários processos: um principal e os filhos (vídeo,
/// áudio, janelas). Excluir a árvore do principal tira o Discord inteiro.
/// Devolve `null` se o Discord não está aberto.
///
/// O Windows só exclui **uma** árvore por captura: com dois Discord abertos
/// (ex.: normal e PTB), lança [DiscordError].
int? discordRoot(List<ProcessEntry> processes) {
  final discordPids = {
    for (final p in processes)
      if (isDiscord(p.name)) p.pid,
  };
  final roots = [
    for (final p in processes)
      if (isDiscord(p.name) && !discordPids.contains(p.parentPid)) p.pid,
  ];
  if (roots.length > 1) {
    throw const DiscordError(
      'dois_discord',
      'Há mais de um Discord aberto. Feche um deles para transmitir o som '
          'do PC sem o Discord.',
    );
  }
  return roots.firstOrNull;
}

/// PIDs do Discord na saída de `tasklist /FO CSV /NH`.
Set<int> discordPidsFromTasklist(String csv) => {
  for (final line in csv.split('\n'))
    if (_csvFields(line) case [final name, final pid, ...] when isDiscord(name))
      ?int.tryParse(pid),
};

/// Processos na saída CSV do `Get-CimInstance Win32_Process`:
/// `"nome","pid","pai"` (o cabeçalho é pulado por não ter números).
List<ProcessEntry> processesFromCim(String csv) => [
  for (final line in csv.split('\n'))
    if (_csvFields(line) case [final name, final pid, final parent])
      if ((int.tryParse(pid), int.tryParse(parent)) case (
        final int p,
        final int pp,
      ))
        (name: name, pid: p, parentPid: pp),
];

List<String> _csvFields(String line) => [
  for (final m in RegExp(r'"([^"]*)"').allMatches(line)) m[1]!,
];

/// O Discord está fora da exclusão? Acontece se ele abriu depois do início
/// (sem exclusão) ou se fechou e abriu de novo (outro PID principal).
bool discordLeaks({required int? excludedRoot, required Set<int> running}) =>
    running.isNotEmpty &&
    (excludedRoot == null || !running.contains(excludedRoot));

class DiscordError implements Exception {
  const DiscordError(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'DiscordError($code): $message';
}

/// Lista os processos com nome, PID e pai (≈1 s; só no início).
Future<List<ProcessEntry>> listProcesses() async {
  final r = await Process.run('powershell', [
    '-NoProfile',
    '-c',
    'Get-CimInstance Win32_Process | '
        'Select-Object Name,ProcessId,ParentProcessId | '
        'ConvertTo-Csv -NoTypeInformation',
  ]);
  return processesFromCim(r.stdout as String);
}

/// PIDs do Discord abertos agora (rápido: dá para chamar a cada poucos s).
Future<Set<int>> runningDiscordPids() async {
  final r = await Process.run('tasklist', ['/FO', 'CSV', '/NH']);
  return discordPidsFromTasklist(r.stdout as String);
}
