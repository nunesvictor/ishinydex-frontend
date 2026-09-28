/// Página no formato do DRF: `{count, next, previous, results}`.
class Paginated<T> {
  const Paginated({required this.count, required this.results, this.next});

  factory Paginated.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) => Paginated(
    count: json['count'] as int,
    next: json['next'] as String?,
    results: [
      for (final item in json['results'] as List<dynamic>)
        fromJson(item as Map<String, dynamic>),
    ],
  );

  final int count;
  final String? next;
  final List<T> results;

  bool get hasNext => next != null;
}
