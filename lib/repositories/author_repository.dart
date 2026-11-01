import '../models/author.dart';
import '../models/page_result.dart';
import '../models/author_query.dart';

abstract interface class AuthorRepository {
  Future<PageResult<Author>> find(AuthorQuery query);
  Future<List<Author>> findAll();
  Future<Author?> findById(int id);
  Future<Author> create(Author author);
  Future<Author> update(Author author);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
}
