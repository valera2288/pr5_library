class PublisherQuery {
  final String search;
  final String? city;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;

  const PublisherQuery({
    this.search = '',
    this.city,
    this.sortField = 'name',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  static const _unset = Object();

  PublisherQuery copyWith({
    String? search,
    Object? city = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return PublisherQuery(
      search: search ?? this.search,
      city: city == _unset ? this.city : city as String?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  PublisherQuery withPage(int p) => PublisherQuery(
        search: search,
        city: city,
        sortField: sortField,
        sortAscending: sortAscending,
        page: p,
        size: size,
        includeDeleted: includeDeleted,
      );

  Map<String, String> toQueryParameters() {
    final p = <String, String>{};
    if (search.isNotEmpty) p['search'] = search;
    if (city != null) p['city'] = city!;
    if (sortField != 'name') p['sort'] = sortField;
    if (!sortAscending) p['sort'] = '${p['sort'] ?? sortField},desc';
    if (page != 1) p['page'] = page.toString();
    if (size != 10) p['size'] = size.toString();
    if (includeDeleted) p['deleted'] = '1';
    return p;
  }

  factory PublisherQuery.fromUri(Uri uri) {
    final p = uri.queryParameters;
    bool asc = true;
    String sf = 'name';
    final s = p['sort'];
    if (s != null) {
      final parts = s.split(',');
      sf = parts[0];
      if (parts.length > 1 && parts[1] == 'desc') asc = false;
    }
    return PublisherQuery(
      search: p['search'] ?? '',
      city: p['city'],
      sortField: sf,
      sortAscending: asc,
      page: int.tryParse(p['page'] ?? '') ?? 1,
      size: int.tryParse(p['size'] ?? '') ?? 10,
      includeDeleted: p['deleted'] == '1',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublisherQuery &&
          search == other.search &&
          city == other.city &&
          sortField == other.sortField &&
          sortAscending == other.sortAscending &&
          page == other.page &&
          size == other.size &&
          includeDeleted == other.includeDeleted;

  @override
  int get hashCode => Object.hash(
      search, city, sortField, sortAscending, page, size, includeDeleted);
}
