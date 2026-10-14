import 'package:flutter/material.dart';
import 'package:ishinydex/core/l10n/l10n.dart';
import 'package:ishinydex/core/l10n/problem.dart';
import 'package:ishinydex/features/settings/settings_providers.dart';

/// Data de captura digitável (PC), no formato escolhido nos Ajustes, com um
/// botão que abre o calendário.
class CaptureDateField extends StatefulWidget {
  const CaptureDateField({
    required this.value,
    required this.pattern,
    required this.onChanged,
    required this.onPickFromCalendar,
    super.key,
  });

  final DateTime? value;
  final CaptureDatePattern pattern;

  /// Data válida (ou `null` se vazia/inválida) e o erro, se houver.
  final void Function(DateTime? date, Problem? error) onChanged;
  final VoidCallback onPickFromCalendar;

  @override
  State<CaptureDateField> createState() => _CaptureDateFieldState();
}

class _CaptureDateFieldState extends State<CaptureDateField> {
  late final _controller = TextEditingController(text: _format(widget.value));
  Problem? _error;

  String _format(DateTime? date) =>
      date == null ? '' : widget.pattern.format(date);

  @override
  void didUpdateWidget(CaptureDateField old) {
    super.didUpdateWidget(old);
    // Data vinda do calendário: reescreve o texto (e limpa o erro).
    final picked = widget.value != null && widget.value != old.value;
    if (picked || widget.pattern.hint != old.pattern.hint) {
      _controller.text = _format(widget.value);
      _error = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final result = widget.pattern.parse(text);
    setState(() => _error = result.error);
    widget.onChanged(result.date, result.error);
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    keyboardType: TextInputType.datetime,
    decoration: InputDecoration(
      labelText: context.l10n.captureDate,
      hintText: widget.pattern.hint,
      errorText: switch (_error) {
        final error? => context.l10n.problem(error),
        null => null,
      },
      prefixIcon: const Icon(Icons.event),
      suffixIcon: IconButton(
        tooltip: context.l10n.pickInCalendar,
        onPressed: widget.onPickFromCalendar,
        icon: const Icon(Icons.calendar_month),
      ),
    ),
    onChanged: _onChanged,
  );
}
