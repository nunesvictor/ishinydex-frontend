import 'package:flutter_riverpod/flutter_riverpod.dart';

/// O relógio do app: as caçadas e a data de corte do HOME (#222). Nos
/// testes, fixo.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
