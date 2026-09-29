import 'package:flutter/material.dart';
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
  final void Function(DateTime? date, String? error) onChanged;
  final VoidCallback onPickFromCalendar;

  @override
  State<CaptureDateField> createState() => _CaptureDateFieldState();
}

class _CaptureDateFieldState extends State<CaptureDateField> {
  late final _controller = TextEditingController(text: _format(widget.value));
  String? _error;

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
      labelText: 'Data de captura',
      hintText: widget.pattern.hint,
      errorText: _error,
      prefixIcon: const Icon(Icons.event),
      suffixIcon: IconButton(
        tooltip: 'Escolher no calendário',
        onPressed: widget.onPickFromCalendar,
        icon: const Icon(Icons.calendar_month),
      ),
    ),
    onChanged: _onChanged,
  );
}
