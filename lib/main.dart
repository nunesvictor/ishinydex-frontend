import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/app.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/features/catalog/catalog_providers.dart';

Future<void> main() async {
  // Só faz algo no modo demonstração com CATALOG_URL (GitHub Pages).
  final overrides = await catalogOverrides(Env.fromEnvironment(), Dio());
  runApp(
    ProviderScope(
      retry: noRetry,
      overrides: overrides,
      child: const IShinyDexApp(),
    ),
  );
}
