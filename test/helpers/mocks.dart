import 'package:ishinydex/features/personal_dex/domain/personal_dex_repository.dart';
import 'package:ishinydex/features/shiny_locks/domain/shiny_lock_repository.dart';
import 'package:ishinydex/features/specimens/domain/specimen_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockPersonalDexRepository extends Mock implements PersonalDexRepository;

class MockSpecimenRepository extends Mock implements SpecimenRepository;

class MockShinyLockRepository extends Mock implements ShinyLockRepository;
