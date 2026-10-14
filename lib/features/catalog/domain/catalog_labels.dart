/// Os rótulos de um texto do catálogo em cada idioma da interface
/// (backend#105): `{"en": …, "pt-BR": …}`. Catálogos antigos não têm:
/// vazio, e vale o `label` em pt-BR.
Map<String, String> catalogLabels(Object? json) => {
  for (final MapEntry(:key, :value)
      in ((json as Map<String, dynamic>?) ?? const <String, dynamic>{}).entries)
    key: value as String,
};
