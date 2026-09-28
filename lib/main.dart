import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/app.dart';

void main() {
  runApp(const ProviderScope(retry: noRetry, child: IShinyDexApp()));
}
