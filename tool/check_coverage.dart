// Lê coverage/lcov.info e falha se a cobertura de linhas ficar abaixo do
// mínimo. Arquivos gerados e o main.dart ficam de fora.
//
// Uso: dart run tool/check_coverage.dart [minimo=100]
import 'dart:io';

const _excluded = ['.g.dart', '.freezed.dart', 'lib/main.dart'];

void main(List<String> args) {
  final minimum = args.isEmpty ? 100.0 : double.parse(args.first);
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    stderr.writeln(
      'coverage/lcov.info não encontrado. Rode: flutter test --coverage',
    );
    exit(2);
  }

  final reported = <String>{};
  final uncovered = <String, List<int>>{};
  var total = 0;
  var hit = 0;
  String? current;
  var skip = false;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = line.substring(3);
      reported.add(current);
      skip = _excluded.any(current.endsWith);
    } else if (line.startsWith('DA:') && !skip) {
      final [lineNumber, count, ...] = line.substring(3).split(',');
      total++;
      if (int.parse(count) > 0) {
        hit++;
      } else {
        uncovered.putIfAbsent(current!, () => []).add(int.parse(lineNumber));
      }
    }
  }

  final percent = total == 0 ? 100.0 : hit * 100 / total;
  stdout.writeln(
    'Cobertura: ${percent.toStringAsFixed(2)}% ($hit/$total linhas)',
  );
  for (final MapEntry(key: path, value: lines) in uncovered.entries) {
    stdout.writeln('  $path: ${lines.join(', ')}');
  }
  // Arquivos que nenhum teste importou não aparecem no lcov.info.
  final missing = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path)
      .where((path) => path.endsWith('.dart'))
      .where((path) => !_excluded.any(path.endsWith))
      .where((path) => !reported.contains(path))
      .where((path) => !_isInterfaceOnly(File(path).readAsStringSync()))
      .toList();
  if (missing.isNotEmpty) {
    stderr.writeln('Arquivos sem nenhum teste:\n  ${missing.join('\n  ')}');
    exit(1);
  }
  if (percent < minimum) {
    stderr.writeln('Abaixo do mínimo de $minimum%.');
    exit(1);
  }
}

/// Interfaces (`abstract interface class`) não têm linhas executáveis.
///
/// Um corpo de método aparece como `) {` ou `) async {`. Parâmetros nomeados
/// (`metodo({`) não contam: vêm depois de `(`, não de `)`.
bool _isInterfaceOnly(String source) =>
    source.contains('abstract interface class') &&
    !source.contains('=>') &&
    !RegExp(r'\)\s*(async\s*)?\{').hasMatch(source);
