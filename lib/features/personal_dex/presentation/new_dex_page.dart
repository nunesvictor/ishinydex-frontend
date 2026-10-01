import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';

/// Regras do conjunto padrão, as mesmas de `home/services.py` no backend.
const List<String> standardSetRules = [
  _ruleBattleOnly,
  _ruleDefaultFormOnly,
  _ruleExcludedForms,
  _ruleExcludedVariants,
  _ruleAlcremie,
];

const _ruleBattleOnly =
    'Todas as formas cadastradas que não são só de batalha (megas, '
    'gigantamax e afins ficam de fora).';
const _ruleDefaultFormOnly =
    'Arceus, Calyrex, Genesect, Koraidon, Miraidon, Mothim, Pichu, '
    'Scatterbug, Silvally e Spewpa: só a forma padrão.';
const _ruleExcludedForms =
    'Sem formas totem, "origin", "power-construct", "starter", Eternamax, '
    'Greninja Battle Bond e Minior Red Meteor.';
const _ruleExcludedVariants =
    'Sem as variações de Calyrex, Kyurem, Necrozma, Ogerpon, Pikachu e '
    'Rockruff.';
const _ruleAlcremie = 'Alcremie: só as variações "vanilla".';

/// Fluxo do dex personalizado (escolher as formas). Ainda não existe: por
/// enquanto só avisa. É o ponto a substituir quando o fluxo for definido.
Future<void> openCustomDexFlow(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Em breve'),
    content: const Text(
      'Escolher as formas de um dex personalizado ainda não está disponível. '
      'Por enquanto, crie um dex com o conjunto padrão.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Entendi'),
      ),
    ],
  ),
);

/// Cadastro de um PersonalDex. Retorna o dex criado.
class NewDexPage extends ConsumerStatefulWidget {
  const NewDexPage({super.key});

  @override
  ConsumerState<NewDexPage> createState() => _NewDexPageState();
}

class _NewDexPageState extends ConsumerState<NewDexPage> {
  final _name = TextEditingController();
  bool _isShinyDex = false;
  bool _forceNewBox = false;
  bool _saving = false;
  ValidationFailure? _validation;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = ref.watch(dexPreviewProvider(_forceNewBox));
    final canCreate = !_saving && (preview.value?.enoughSpace ?? false);
    return Scaffold(
      appBar: AppBar(title: const Text('Novo PersonalDex')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Tipo de dex', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.check_circle),
                  title: Text('Padrão'),
                  subtitle: Text(
                    'O conjunto de formas usado pelo iShinyDex, na ordem da '
                    'Pokédex nacional.',
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.tune),
                  // Wrap: em tela estreita o chip desce para a linha de baixo.
                  title: const Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Personalizado'),
                      Chip(
                        label: Text('Em breve'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  subtitle: const Text('Escolher as formas uma a uma.'),
                  onTap: () => openCustomDexFlow(context),
                ),
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('O que entra no conjunto padrão?'),
                children: [
                  for (final rule in standardSetRules)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.circle, size: 8),
                      title: Text(rule),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: 'Nome',
                  errorText: _validation?.errorFor('name'),
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dex shiny'),
                subtitle: const Text(
                  'Mostra os sprites shiny e prioriza espécimes shiny ao '
                  'depositar.',
                ),
                value: _isShinyDex,
                onChanged: (v) => setState(() => _isShinyDex = v),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Nova box a cada geração'),
                subtitle: const Text(
                  'Cada geração começa no primeiro slot de uma box; sobram '
                  'slots vazios no fim da box anterior.',
                ),
                value: _forceNewBox,
                onChanged: (v) => setState(() => _forceNewBox = v),
              ),
              const SizedBox(height: 8),
              _PreviewCard(preview: preview, forceNewBox: _forceNewBox),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: canCreate ? _create : null,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Criar PersonalDex'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create() async {
    setState(() {
      _saving = true;
      _validation = null;
      _error = null;
    });
    try {
      final dex = await ref
          .read(personalDexRepositoryProvider)
          .createDex(
            name: _name.text.trim(),
            isShinyDex: _isShinyDex,
            forceNewBox: _forceNewBox,
          );
      // O dex novo ocupou boxes: a simulação e a lista mudaram.
      ref
        ..invalidate(dexPreviewProvider)
        ..invalidate(dexListProvider);
      if (mounted) Navigator.of(context).pop(dex);
    } on AppFailure catch (failure) {
      setState(() {
        _saving = false;
        _validation = failure is ValidationFailure ? failure : null;
        _error = failure.message;
      });
    }
  }
}

/// Resumo do que será criado, vindo da simulação da API.
class _PreviewCard extends ConsumerWidget {
  const _PreviewCard({required this.preview, required this.forceNewBox});

  final AsyncValue<DexPreview> preview;
  final bool forceNewBox;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: switch (preview) {
        AsyncData(value: DexPreview(enoughSpace: false)) =>
          scheme.errorContainer,
        _ => null,
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (preview) {
          AsyncData(value: final p) when p.enoughSpace => Text(switch (p
              .firstBox) {
            // Dex inteiro em boxes novas, criadas depois da última.
            null =>
              '${p.forms} formas em ${p.boxesNeeded} boxes novas, '
                  'criadas no fim.',
            final first =>
              '${p.forms} formas em ${p.boxesNeeded} boxes, a partir da '
                  '${first.name}'
                  '${p.boxesToCreate > 0 ? ' (cria ${_boxes(p.boxesToCreate)} no fim)' : ''}.',
          }),
          AsyncData(value: final p) => Text(
            'Não há espaço: este dex precisa de ${p.boxesNeeded} boxes livres '
            'seguidas, a maior sequência livre tem ${p.largestFreeRun}, e o '
            'HOME tem no máximo $homeMaxBoxes boxes.',
            style: TextStyle(color: scheme.onErrorContainer),
          ),
          AsyncError(:final error) => Row(
            children: [
              Expanded(
                child: Text(
                  error is AppFailure
                      ? error.message
                      : 'Não foi possível simular o dex.',
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.invalidate(dexPreviewProvider(forceNewBox)),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
          _ => const LinearProgressIndicator(),
        },
      ),
    );
  }
}

/// "1 box nova" / "3 boxes novas".
String _boxes(int count) => count == 1 ? '1 box nova' : '$count boxes novas';
