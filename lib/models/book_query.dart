class BookQuery {
  final String search;
  final int? genreId;
  final int? publisherId;
  final int? yearFrom;
  final int? yearTo;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;

  const BookQuery({
    this.search = '',
    this.genreId,
    this.publisherId,
    this.yearFrom,
    this.yearTo,
    this.sortField = 'title',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  static const _unset = Object();

  BookQuery copyWith({
    String? search,
    Object? genreId = _unset,
    Object? publisherId = _unset,
    Object? yearFrom = _unset,
    Object? yearTo = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return BookQuery(
      search: search ?? this.search,
      genreId: genreId == _unset ? this.genreId : genreId as int?,
      publisherId:
          publisherId == _unset ? this.publisherId : publisherId as int?,
      yearFrom: yearFrom == _unset ? this.yearFrom : yearFrom as int?,
      yearTo: yearTo == _unset ? this.yearTo : yearTo as int?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  BookQuery withPage(int newPage) => BookQuery(
        search: search,
        genreId: genreId,
        publisherId: publisherId,
        yearFrom: yearFrom,
        yearTo: yearTo,
        sortField: sortField,
        sortAscending: sortAscending,
        page: newPage,
        size: size,
        includeDeleted: includeDeleted,
      );

  Map<String, String> toQueryParameters() {
    final params = <String, String>{};
    if (search.isNotEmpty) params['search'] = search;
    if (genreId != null) params['genreId'] = genreId.toString();
    if (publisherId != null) params['publisherId'] = publisherId.toString();
    if (yearFrom != null) params['yearFrom'] = yearFrom.toString();
    if (yearTo != null) params['yearTo'] = yearTo.toString();
    if (sortField != 'title') params['sort'] = sortField;
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

  factory BookQuery.fromUri(Uri uri) {
    final p = uri.queryParameters;
    bool sortAsc = true;
    String sortField = 'title';
    final sortParam = p['sort'];
    if (sortParam != null) {
      final parts = sortParam.split(',');
      sortField = parts[0];
      if (parts.length > 1 && parts[1] == 'desc') sortAsc = false;
    }
    return BookQuery(
      search: p['search'] ?? '',
      genreId: p['genreId'] != null ? int.tryParse(p['genreId']!) : null,
      publisherId:
          p['publisherId'] != null ? int.tryParse(p['publisherId']!) : null,
      yearFrom: p['yearFrom'] != null ? int.tryParse(p['yearFrom']!) : null,
      yearTo: p['yearTo'] != null ? int.tryParse(p['yearTo']!) : null,
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
      other is BookQuery &&
          search == other.search &&
          genreId == other.genreId &&
          publisherId == other.publisherId &&
          yearFrom == other.yearFrom &&
          yearTo == other.yearTo &&
          sortField == other.sortField &&
          sortAscending == other.sortAscending &&
          page == other.page &&
          size == other.size &&
          includeDeleted == other.includeDeleted;

  @override
  int get hashCode => Object.hash(
        search,
        genreId,
        publisherId,
        yearFrom,
        yearTo,
        sortField,
        sortAscending,
        page,
        size,
        includeDeleted,
      );
}
