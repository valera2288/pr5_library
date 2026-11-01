import '../models/genre.dart';
import '../models/page_result.dart';
import '../models/genre_query.dart';

abstract interface class GenreRepository {
  Future<PageResult<Genre>> find(GenreQuery q);
  Future<List<Genre>> findAll();
  Future<Genre?> findById(int id);
  Future<Genre> create(Genre g);
  Future<Genre> update(Genre g);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
}
