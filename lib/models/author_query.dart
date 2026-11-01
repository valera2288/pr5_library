class AuthorQuery {
  final String search;
  final String? country;
  final int? birthYearFrom;
  final int? birthYearTo;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;

  const AuthorQuery({
    this.search = '',
    this.country,
    this.birthYearFrom,
    this.birthYearTo,
    this.sortField = 'fullName',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  static const _unset = Object();

  AuthorQuery copyWith({
    String? search,
    Object? country = _unset,
    Object? birthYearFrom = _unset,
    Object? birthYearTo = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return AuthorQuery(
      search: search ?? this.search,
      country: country == _unset ? this.country : country as String?,
      birthYearFrom:
          birthYearFrom == _unset ? this.birthYearFrom : birthYearFrom as int?,
      birthYearTo:
          birthYearTo == _unset ? this.birthYearTo : birthYearTo as int?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  AuthorQuery withPage(int newPage) => AuthorQuery(
        search: search,
        country: country,
        birthYearFrom: birthYearFrom,
        birthYearTo: birthYearTo,
        sortField: sortField,
        sortAscending: sortAscending,
        page: newPage,
        size: size,
        includeDeleted: includeDeleted,
      );

  Map<String, String> toQueryParameters() {
    final params = <String, String>{};
    if (search.isNotEmpty) params['search'] = search;
    if (country != null) params['country'] = country!;
    if (birthYearFrom != null) params['yearFrom'] = birthYearFrom.toString();
    if (birthYearTo != null) params['yearTo'] = birthYearTo.toString();
    if (sortField != 'fullName') params['sort'] = sortField;
    if (!sortAscending) {
      params['sort'] = '${params['sort'] ?? sortField},desc';
    } else if (params.containsKey('sort')) {
      params['sort'] = '${params['sort']},asc';
    }
    if (page != 1) params['page'] = page.toString();
    if (size != 10) params['size'] = size.toString();
    if (includeDeleted) params['deleted'] = '1';
    return params;
  }

  factory AuthorQuery.fromUri(Uri uri) {
    final p = uri.queryParameters;
    bool sortAsc = true;
    String sortField = 'fullName';
    final sortParam = p['sort'];
    if (sortParam != null) {
      final parts = sortParam.split(',');
      sortField = parts[0];
      if (parts.length > 1 && parts[1] == 'desc') sortAsc = false;
    }
    return AuthorQuery(
      search: p['search'] ?? '',
      country: p['country'],
      birthYearFrom:
          p['yearFrom'] != null ? int.tryParse(p['yearFrom']!) : null,
      birthYearTo: p['yearTo'] != null ? int.tryParse(p['yearTo']!) : null,
      sortField: sortField,
      sortAscending: sortAsc,
      page: p['page'] != null ? (int.tryParse(p['page']!) ?? 1) : 1,
      size: p['size'] != null ? (int.tryParse(p['size']!) ?? 10) : 10,
      includeDeleted: p['deleted'] == '1',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthorQuery &&
          search == other.search &&
          country == other.country &&
          birthYearFrom == other.birthYearFrom &&
          birthYearTo == other.birthYearTo &&
          sortField == other.sortField &&
          sortAscending == other.sortAscending &&
          page == other.page &&
          size == other.size &&
          includeDeleted == other.includeDeleted;

  @override
  int get hashCode => Object.hash(
        search,
        country,
        birthYearFrom,
        birthYearTo,
        sortField,
        sortAscending,
        page,
        size,
        includeDeleted,
      );
}
