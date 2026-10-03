import 'package:flutter/material.dart';
import 'package:ishinydex/core/theme/app_theme.dart';

/// O app não abriu (modo local sem catálogo, dados de uma versão mais nova
/// do app...): explica e deixa tentar de novo, em vez de uma tela branca.
class BootFailureApp extends StatelessWidget {
  const BootFailureApp({required this.error, required this.onRetry, super.key});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                const Icon(Icons.cloud_off, size: 48),
                const Text(
                  'Não foi possível abrir o iShinyDex.',
                  textAlign: TextAlign.center,
                ),
                Text(switch (error) {
                  FormatException(:final message) => message,
                  _ => 'Confira a conexão e tente de novo.',
                }, textAlign: TextAlign.center),
                // O detalhe técnico, para quem for relatar o problema.
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
