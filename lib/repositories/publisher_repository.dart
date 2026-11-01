import '../models/publisher.dart';
import '../models/page_result.dart';
import '../models/publisher_query.dart';

abstract interface class PublisherRepository {
  Future<PageResult<Publisher>> find(PublisherQuery q);
  Future<List<Publisher>> findAll();
  Future<Publisher?> findById(int id);
  Future<Publisher> create(Publisher p);
  Future<Publisher> update(Publisher p);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
  Future<int> countBooksUsing(int publisherId);
}
