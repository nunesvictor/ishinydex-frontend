import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/widgets/async_views.dart';
import 'package:ishinydex/features/catalog/domain/catalog.dart';
import 'package:ishinydex/features/moves/domain/moves_data.dart';
import 'package:ishinydex/features/moves/presentation/moves_widgets.dart';
import 'package:ishinydex/features/teams/assistant/team_tools.dart';
import 'package:ishinydex/features/teams/domain/models.dart';
import 'package:ishinydex/features/teams/teams_providers.dart';
import 'package:material_ui/material_ui.dart';

/// Spike #418: liga o atalho do assistente (`--dart-define=AI_SPIKE=true`).
/// Sem a flag, nada do assistente aparece e o app fica como sempre.
const aiSpike = bool.fromEnvironment('AI_SPIKE');

/// O modelo do spike: Gemma 4 E2B (Apache 2.0). Na web, o arquivo exportado
/// para o `@litert-lm/core` (WebGPU); no nativo, o genérico (GPU por Metal,
/// senão CPU).
LiteRtLmVariant get _variant => kIsWeb
    ? LiteRtLmModels.gemma4E2bIt.web
    : LiteRtLmModels.gemma4E2bIt.generic;

/// As instruções e o time já analisado: um modelo pequeno nem sempre chama
/// a ferramenta para descobrir o time (no primeiro teste, pediu ao usuário
/// a lista), então a análise vai junto desde o começo. As ferramentas ficam
/// para as ações: sugerir e simular trocas, sugerir golpes.
String _system(TeamTools tools) =>
    'Você é o assistente de times do iShinyDex, um app de Pokémon shiny. '
    'Responda sempre em português do Brasil, curto e direto. '
    'O time do usuário, já analisado pelo app, está abaixo em JSON; use '
    'esses dados e não peça a lista ao usuário. Nunca invente números, '
    'tipos, golpes ou notas. Para sugerir trocas, chame sugerir_formas e '
    'confira com simular_troca; para golpes, chame sugerir_golpes. Prefira '
    'Pokémon que o usuário já tem.\n\n'
    'Time: ${jsonEncode(tools.analyze())}';

const _examples = [
  'Como está meu time?',
  'O que eu troco para melhorar a nota?',
  'Que golpes valem a pena?',
];

/// Uma linha do chat.
sealed class _Turn;

class _UserTurn extends _Turn {
  _UserTurn(this.text);
  final String text;
}

class _ModelTurn extends _Turn {
  final text = StringBuffer();
}

class _ToolTurn extends _Turn {
  _ToolTurn(this.name, this.args);
  final String name;
  final Map<String, Object?> args;
  Map<String, Object?>? result;
}

/// A tela do assistente do time [teamId] (spike #418, sem tradução nem
/// testes de tela): baixa o modelo, mede os tempos e conversa com as
/// ferramentas de [TeamTools].
class AssistantPage extends ConsumerWidget {
  const AssistantPage({required this.teamId, super.key});

  final int teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref
        .watch(teamsProvider)
        .value
        ?.where((t) => t.id == teamId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Assistente (teste)')),
      body: switch (ref.watch(teamsProvider)) {
        AsyncData() when team == null => const EmptyView(
          message: 'Time não encontrado.',
        ),
        AsyncData() => MovesGate.page(
          builder: (data, catalog) => _AssistantBody(
            team: team!,
            catalog: catalog,
            data: data,
            owned: ref.watch(ownedFormsProvider).value ?? const {},
          ),
        ),
        AsyncError(:final error) => ErrorView(error: error),
        _ => const LoadingView(),
      },
    );
  }
}

class _AssistantBody extends StatefulWidget {
  const _AssistantBody({
    required this.team,
    required this.catalog,
    required this.data,
    required this.owned,
  });

  final Team team;
  final Catalog catalog;
  final MovesData data;
  final Set<int> owned;

  @override
  State<_AssistantBody> createState() => _AssistantBodyState();
}

class _AssistantBodyState extends State<_AssistantBody> {
  static bool _initialized = false;

  late final _tools = TeamTools(
    team: widget.team,
    catalog: widget.catalog,
    data: widget.data,
    owned: widget.owned,
  );
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _turns = <_Turn>[];
  final _metrics = <String>[];

  /// null: não começou; 0 a 100: baixando.
  int? _progress;
  String _phase = 'Modelo não carregado';
  Object? _error;
  InferenceModel? _model;
  InferenceChat? _chat;
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    unawaited(_chat?.close());
    unawaited(_model?.close());
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _progress = 0;
      _phase = 'Baixando o modelo';
    });
    try {
      if (!_initialized) {
        await FlutterEdgeAi.initialize(
          inferenceEngines: const [LiteRtLmEngine()],
          // O arquivo da web tem 2,0 GB: perto do limite de um ArrayBuffer;
          // o OPFS grava em fluxo, sem carregar tudo na memória.
          webStorageMode: WebStorageMode.streaming,
        );
        _initialized = true;
      }
      final download = Stopwatch()..start();
      await FlutterEdgeAi.installModelFromCatalog(_variant).withProgress((p) {
        if (mounted) setState(() => _progress = p);
      }).install();
      _metric('Download (ou cache): ${_seconds(download)}');
      setState(() => _phase = 'Carregando na memória');
      final load = Stopwatch()..start();
      final model = await FlutterEdgeAi.getActiveModel(
        defaults: _variant.runtimeDefaults,
        maxTokens: 4096,
      );
      final chat = await model.openChat(
        tools: [
          for (final t in TeamTools.declarations)
            Tool(
              name: t.name,
              description: t.description,
              parameters: t.parameters,
            ),
        ],
        supportsFunctionCalls: true,
        systemInstruction: _system(_tools),
        maxOutputTokens: 512,
      );
      _metric('Carregar: ${_seconds(load)}');
      if (!mounted) {
        await chat.close();
        await model.close();
        return;
      }
      setState(() {
        _model = model;
        _chat = chat;
        _phase = 'Pronto';
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _phase = 'Falhou';
        });
      }
    }
  }

  Future<void> _send(String text) async {
    final chat = _chat;
    if (chat == null || text.trim().isEmpty || _busy) return;
    final reply = _ModelTurn();
    setState(() {
      _turns
        ..add(_UserTurn(text.trim()))
        ..add(reply);
      _input.clear();
      _busy = true;
    });
    final turn = Stopwatch()..start();
    Duration? first;
    var tokens = 0;
    try {
      await chat.addQueryChunk(Message.text(text: text.trim(), isUser: true));
      await for (final chunk in chat.generateChatResponseWithTools(
        maxToolTurns: 4,
        onToolCall: (call) {
          debugPrint('[spike-ia] ferramenta: ${call.name} ${call.args}');
          final tool = _ToolTurn(call.name, call.args);
          setState(() => _turns.insert(_turns.length - 1, tool));
          final result = _tools.run(call.name, call.args);
          debugPrint('[spike-ia] resultado: ${jsonEncode(result)}');
          setState(() => tool.result = result);
          return result;
        },
      )) {
        if (chunk is TextResponse) {
          first ??= turn.elapsed;
          tokens++;
          setState(() => reply.text.write(chunk.token));
          _toBottom();
        }
      }
      final total = turn.elapsed;
      debugPrint('[spike-ia] resposta: ${reply.text}');
      _metric(
        'Resposta: 1º token em ${_seconds(null, first)}, '
        'total ${_seconds(null, total)}, '
        '$tokens pedaços',
      );
    } on Object catch (error) {
      setState(() => reply.text.write('⚠️ $error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _metric(String line) {
    debugPrint('[spike-ia] $line');
    if (mounted) setState(() => _metrics.add(line));
  }

  static String _seconds(Stopwatch? watch, [Duration? duration]) {
    final d = duration ?? watch!.elapsed;
    return '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = _chat != null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Card.outlined(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Text(
                    'Gemma 4 E2B · ${kIsWeb ? 'web (WebGPU)' : 'nativo (GPU)'}'
                    ' · ${kIsWeb ? '2,0' : '2,6'} GB',
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    _progress != null && _progress! < 100 && !ready
                        ? '$_phase: $_progress%'
                        : _phase,
                  ),
                  if (_progress != null && _progress! < 100 && !ready)
                    LinearProgressIndicator(value: _progress! / 100),
                  if (_error != null)
                    SelectableText(
                      '$_error',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  for (final m in _metrics)
                    Text(m, style: theme.textTheme.bodySmall),
                  if (!ready && (_progress == null || _error != null))
                    FilledButton(
                      onPressed: _start,
                      child: const Text('Baixar e carregar o modelo'),
                    ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [for (final t in _turns) _TurnView(t)],
          ),
        ),
        if (ready && !_busy)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              spacing: 8,
              children: [
                for (final e in _examples)
                  ActionChip(label: Text(e), onPressed: () => _send(e)),
              ],
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    enabled: ready && !_busy,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: const InputDecoration(
                      hintText: 'Pergunte sobre o time',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Enviar',
                  onPressed: ready && !_busy ? () => _send(_input.text) : null,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TurnView extends StatelessWidget {
  const _TurnView(this.turn);

  final _Turn turn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return switch (turn) {
      _UserTurn(:final text) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(text),
        ),
      ),
      _ModelTurn(:final text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SelectableText(text.isEmpty ? '…' : text.toString()),
      ),
      final _ToolTurn tool => ExpansionTile(
        dense: true,
        tilePadding: EdgeInsets.zero,
        leading: const Icon(Icons.build_outlined, size: 18),
        title: Text(
          '${tool.name}(${tool.args.isEmpty ? '' : jsonEncode(tool.args)})',
          style: theme.textTheme.bodySmall,
        ),
        children: [
          SelectableText(
            const JsonEncoder.withIndent('  ').convert(tool.result),
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    };
  }
}
