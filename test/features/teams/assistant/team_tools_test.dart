import 'package:flutter_test/flutter_test.dart';
import 'package:ishinydex/features/teams/assistant/team_tools.dart';
import 'package:ishinydex/features/teams/domain/models.dart';

import '../team_fixture.dart';

void main() {
  final catalog = teamCatalog();
  final data = teamMoves();

  TeamTools tools({Set<int> owned = const {}}) => TeamTools(
    team: const Team(
      id: 1,
      name: 'Teste',
      versionGroup: 'scarlet-violet',
      members: [TeamMember(form: 1), TeamMember(form: 1)],
    ),
    catalog: catalog,
    data: data,
    owned: owned,
  );

  test('as declarações têm nome, descrição e parâmetros de objeto', () {
    expect(TeamTools.declarations.map((t) => t.name), [
      'analisar_time',
      'sugerir_formas',
      'sugerir_golpes',
      'simular_troca',
    ]);
    for (final t in TeamTools.declarations) {
      expect(t.parameters['type'], 'object');
      expect(t.description, isNotEmpty);
    }
  });

  test('analisar_time devolve a nota, os membros e os problemas', () {
    final t = tools();
    final result = t.run('analisar_time', {});
    expect(result['nota'], t.synergy.score);
    expect(result['membros'], hasLength(2));
    expect(result['problemas'], isNotEmpty);
    expect(
      (result['problemas']! as List).any((p) => '$p'.contains('vaga')),
      isTrue,
    );
  });

  test('sugerir_formas marca o que o usuário tem', () {
    final result = tools(owned: {2}).run('sugerir_formas', {});
    final sugestoes = result['sugestoes']! as List;
    expect(sugestoes, isNotEmpty);
    expect(
      sugestoes.any((s) => '${(s as Map)['pokemon']}'.contains('(você tem)')),
      isTrue,
    );
  });

  test('sugerir_golpes devolve uma lista', () {
    expect(tools().run('sugerir_golpes', {})['sugestoes'], isA<List>());
  });

  test('simular_troca calcula a diferença e confere os nomes', () {
    final t = tools();
    final name = catalog.formRef(2).displayName;
    final result = t.run('simular_troca', {
      'sai': 'BULBASAUR',
      'entra': name.toLowerCase(),
    });
    expect(result['erro'], isNull);
    expect(result['nota_antes'], t.synergy.score);
    expect(result['diferenca'], (result['nota']! as int) - t.synergy.score);

    expect(
      t.run('simular_troca', {'sai': 'Mew', 'entra': name})['erro'],
      contains('não está no time'),
    );
    expect(
      t.run('simular_troca', {'sai': 'Bulbasaur', 'entra': 'Xyz'})['erro'],
      contains('Não achei'),
    );
  });

  test('ferramenta desconhecida vira erro', () {
    expect(tools().run('outra', {})['erro'], contains('desconhecida'));
  });
}
