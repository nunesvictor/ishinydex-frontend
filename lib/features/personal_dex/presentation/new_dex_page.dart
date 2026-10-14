import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/network/app_failure.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';
import 'package:ishinydex/features/personal_dex/personal_dex_providers.dart';

/// Regras do conjunto padrão, as mesmas de `home/services.py` no backend.
List<String> standardSetRules(AppLocalizations l10n) => [
  l10n.ruleBattleOnly,
  l10n.ruleDefaultFormOnly,
  l10n.ruleExcludedForms,
  l10n.ruleExcludedVariants,
  l10n.ruleAlcremie,
];

/// Fluxo do dex personalizado (escolher as formas). Ainda não existe: por
/// enquanto só avisa. É o ponto a substituir quando o fluxo for definido.
Future<void> openCustomDexFlow(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(context.l10n.comingSoon),
    content: Text(context.l10n.customDexSoon),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.gotIt),
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
      appBar: AppBar(title: Text(context.l10n.dexNew)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(context.l10n.dexType, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.check_circle),
                  title: Text(context.l10n.dexStandard),
                  subtitle: Text(context.l10n.dexStandardSubtitle),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.tune),
                  // Wrap: em tela estreita o chip desce para a linha de baixo.
                  title: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(context.l10n.dexCustom),
                      Chip(
                        label: Text(context.l10n.comingSoon),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  subtitle: Text(context.l10n.dexCustomSubtitle),
                  onTap: () => openCustomDexFlow(context),
                ),
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(context.l10n.standardSetQuestion),
                children: [
                  for (final rule in standardSetRules(context.l10n))
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
                  labelText: context.l10n.fieldName,
                  errorText: context.fieldError(_validation, 'name'),
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.shinyDex),
                subtitle: Text(context.l10n.shinyDexNewSubtitle),
                value: _isShinyDex,
                onChanged: (v) => setState(() => _isShinyDex = v),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.newBoxPerGeneration),
                subtitle: Text(context.l10n.newBoxPerGenerationSubtitle),
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
                    : Text(context.l10n.createDex),
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
        _error = context.failureText(failure);
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
          AsyncData(value: final p) when p.enoughSpace => Text(
            switch (p.firstBox) {
              // Dex inteiro em boxes novas, criadas depois da última.
              null => context.l10n.previewNewBoxes(p.forms, p.boxesNeeded),
              final first => context.l10n.previewFrom(
                p.forms,
                p.boxesNeeded,
                first.name,
                p.boxesToCreate > 0
                    ? context.l10n.previewCreates(p.boxesToCreate)
                    : '',
              ),
            },
          ),
          AsyncData(value: final p) => Text(
            context.l10n.previewNoSpace(
              p.boxesNeeded,
              p.largestFreeRun,
              homeMaxBoxes,
            ),
            style: TextStyle(color: scheme.onErrorContainer),
          ),
          AsyncError(:final error) => Row(
            children: [
              Expanded(
                child: Text(
                  error is AppFailure
                      ? context.failureText(error)
                      : context.l10n.previewError,
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.invalidate(dexPreviewProvider(forceNewBox)),
                child: Text(context.l10n.tryAgain),
              ),
            ],
          ),
          _ => const LinearProgressIndicator(),
        },
      ),
    );
  }
}
