import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';

part 'models.freezed.dart';
part 'models.g.dart';

/// Shiny lock cadastrado à mão (`/shiny-locks/`): formas sem shiny
/// ([ShinyLockType.unobtainable]) ou com shiny só por distribuição
/// ([ShinyLockType.distroOnly]). Só os ativos valem nas caçadas e no
/// detalhe dos slots.
@freezed
abstract class ShinyLock with _$ShinyLock {
  const factory ShinyLock({
    required int id,
    required String caption,
    @JsonKey(fromJson: _lockTypeFromJson, toJson: _lockTypeToJson)
    required ShinyLockType lockType,
    required List<FormRef> forms,
    String? description,
    @Default(true) bool active,
  }) = _ShinyLock;

  factory ShinyLock.fromJson(Map<String, dynamic> json) =>
      _$ShinyLockFromJson(json);
}

ShinyLockType _lockTypeFromJson(String value) =>
    ShinyLockType.fromParam(value) ?? ShinyLockType.unobtainable;

String _lockTypeToJson(ShinyLockType type) => type.param;

/// O que a tela de cadastro envia para criar ou editar um shiny lock. As
/// formas vão inteiras (a tela mostra nome e sprite); a API só recebe os ids.
@freezed
abstract class ShinyLockDraft with _$ShinyLockDraft {
  const factory ShinyLockDraft({
    @Default('') String caption,
    @Default('') String description,
    @Default(ShinyLockType.unobtainable) ShinyLockType lockType,
    @Default(true) bool active,
    @Default(<FormRef>[]) List<FormRef> forms,
  }) = _ShinyLockDraft;

  const ShinyLockDraft._();

  /// Rascunho para editar [lock].
  factory ShinyLockDraft.of(ShinyLock lock) => ShinyLockDraft(
    caption: lock.caption,
    description: lock.description ?? '',
    lockType: lock.lockType,
    active: lock.active,
    forms: lock.forms,
  );

  /// Corpo de `POST`/`PATCH /shiny-locks/`.
  Map<String, dynamic> toJson() => {
    'caption': caption.trim(),
    'description': description.trim(),
    'lock_type': lockType.param,
    'active': active,
    'forms': [for (final form in forms) form.id],
  };
}
