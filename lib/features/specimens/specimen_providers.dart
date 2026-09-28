import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/fake/fake_backend.dart';
import 'package:ishinydex/features/auth/auth_providers.dart';
import 'package:ishinydex/features/specimens/data/http_specimen_repository.dart';
import 'package:ishinydex/features/specimens/domain/models.dart';
import 'package:ishinydex/features/specimens/domain/specimen_repository.dart';

final specimenRepositoryProvider = Provider<SpecimenRepository>((ref) {
  if (ref.watch(envProvider).useFakeApi) return ref.watch(fakeBackendProvider);
  return HttpSpecimenRepository(ref.watch(dioProvider));
});

final FutureProviderFamily<List<Specimen>, int> availableSpecimensProvider =
    FutureProvider.autoDispose.family<List<Specimen>, int>(
      (ref, formId) =>
          ref.watch(specimenRepositoryProvider).fetchAvailable(formId),
    );

final FutureProviderFamily<FormDetail, int> formDetailProvider = FutureProvider
    .autoDispose
    .family<FormDetail, int>(
      (ref, formId) => ref.watch(specimenRepositoryProvider).fetchForm(formId),
    );

final specimenOptionsProvider = FutureProvider<SpecimenOptions>(
  (ref) => ref.watch(specimenRepositoryProvider).fetchOptions(),
);

final FutureProvider<List<Trainer>> trainersProvider =
    FutureProvider.autoDispose<List<Trainer>>(
      (ref) => ref.watch(specimenRepositoryProvider).fetchTrainers(),
    );

/// Ordena candidatos ao depósito: primeiro os que batem com [preferShiny].
List<Specimen> sortForDeposit(
  List<Specimen> specimens, {
  required bool preferShiny,
}) => [...specimens]
  ..sort((a, b) {
    final aMatches = a.isShiny == preferShiny ? 0 : 1;
    final bMatches = b.isShiny == preferShiny ? 0 : 1;
    if (aMatches != bMatches) return aMatches - bMatches;
    return a.id.compareTo(b.id);
  });
