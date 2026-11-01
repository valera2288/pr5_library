import '../models/book.dart';
import '../models/page_result.dart';
import '../models/book_query.dart';

abstract interface class BookRepository {
  Future<PageResult<Book>> find(BookQuery query);
  Future<Book?> findById(int id);
  Future<Book> create(Book book);
  Future<Book> update(Book book);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
  Future<List<Book>> findAll();
  bool isbnExists(String isbn, {int? exceptId});
}
