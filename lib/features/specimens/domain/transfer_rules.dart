import 'package:ishinydex/features/personal_dex/domain/models.dart';

// Restrições do HOME ao mover um Pokémon para um save (frontend#175), das
// notas do gráfico de transferências do r/PokemonHOME e da Bulbapedia. As
// listas são curtas e mudam pouco, por isso ficam aqui e não no catálogo.

/// Formas que o HOME não deixa sair (nomes de forma da PokéAPI).
const unmovableForms = {
  'pikachu-starter',
  'eevee-starter',
  'pichu-spiky-eared',
  'kyurem-black',
  'kyurem-white',
  'necrozma-dusk',
  'necrozma-dawn',
  'calyrex-ice',
  'calyrex-shadow',
};

const _bdsp = {'brilliant-diamond', 'shining-pearl'};

/// Por que o HOME recusa a forma [formName], com a marca de origem [mark],
/// num save de [saveVersion]; `null` = pode ir.
String? transferBlock(String formName, String? mark, String? saveVersion) {
  final bdsp = _bdsp.contains(saveVersion);
  if (unmovableForms.contains(formName)) return 'Essa forma não sai do HOME';
  if (formName == 'spinda' && bdsp) return 'O Spinda não vai para o BDSP';
  if (formName == 'nincada') {
    if (bdsp && mark != 'bdsp') return 'Só o Nincada do BDSP entra no BDSP';
    if (!bdsp && mark == 'bdsp') return 'O Nincada do BDSP só volta ao BDSP';
  }
  return null;
}

/// Aviso (o envio continua liberado): lendários, míticos e Ultracriaturas
/// vindos do GO só entram num save que já obteve aquela forma, e o app não
/// sabe disso. Meltan e Melmetal são a exceção.
String? transferWarning(
  String formName,
  String? mark,
  SpeciesCategory category,
) {
  const special = {
    SpeciesCategory.legendary,
    SpeciesCategory.mythical,
    SpeciesCategory.ultraBeast,
  };
  if (mark != 'go' || !special.contains(category)) return null;
  if (formName == 'meltan' || formName == 'melmetal') return null;
  return 'Do GO: só entra se o save já obteve essa forma';
}

/// Um espécime que não pode ir, ou que vai com aviso.
typedef TransferIssue = ({int id, String name, String message});

/// O resultado de `FakeBackend.transferCheck`: quem pode ir para o save,
/// quem fica (e por quê), os avisos e quantos estão fora da pokédex do
/// jogo (só um aviso: o HOME aceita alguns de fora, como eventos).
class TransferCheck {
  const TransferCheck({
    this.movable = const [],
    this.blocked = const [],
    this.warnings = const [],
    this.outside = 0,
  });

  final List<int> movable;
  final List<TransferIssue> blocked;
  final List<TransferIssue> warnings;
  final int outside;

  /// Algum pode ir: o save fica habilitado.
  bool get allowed => movable.isNotEmpty;
}
