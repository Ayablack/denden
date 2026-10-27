/// Números do painel em pt-BR: ponto nos milhares, vírgula nos decimais.
String _ptBr(double v, int decimals) {
  final fixed = v.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final neg = parts[0].startsWith('-');
  final digits = neg ? parts[0].substring(1) : parts[0];
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write('.');
    b.write(digits[i]);
  }
  final whole = '${neg ? '-' : ''}$b';
  return decimals == 0 ? whole : '$whole,${parts[1]}';
}

/// MB (10^6) abaixo de 1 GB, senão GB (10^9) com 2 casas.
String formatBytes(num bytes) {
  final mb = (bytes / 1e6).round();
  if (mb < 1000) return '${_ptBr(mb.toDouble(), 0)} MB';
  return '${_ptBr(bytes / 1e9, 2)} GB';
}

String formatBrl(num v) {
  final s = _ptBr(v.toDouble(), 2);
  if (s.startsWith('-')) return '-R\$ ${s.substring(1)}';
  return 'R\$ $s';
}

String formatUsd(num v) {
  final s = _ptBr(v.toDouble(), 2);
  if (s.startsWith('-')) return '-US\$ ${s.substring(1)}';
  return 'US\$ $s';
}

String formatPercent(num v) => '${_ptBr(v.toDouble(), 1)}%';
