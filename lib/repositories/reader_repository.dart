import '../models/reader.dart';
import '../models/page_result.dart';
import '../models/reader_query.dart';

abstract interface class ReaderRepository {
  Future<PageResult<Reader>> find(ReaderQuery q);
  Future<List<Reader>> findAll();
  Future<Reader?> findById(int id);
  Future<Reader> create(Reader r);
  Future<Reader> update(Reader r);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
  bool emailExists(String email, {int? exceptId});
}
