import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/loan.dart';
import '../models/page_result.dart';
import 'api/api_crud.dart';

abstract interface class LoanRepository {
  /// [status] — active, overdue, returned или null для всех выдач.
  Future<PageResult<Loan>> find({String? status, int page = 1, int size = 10});

  /// Оформить выдачу. Если свободных экземпляров нет, сервер вернёт 409,
  /// и наружу выйдет ConflictException.
  Future<Loan> issue(
      {required int readerId, required int bookId, int days = 14});

  Future<Loan> returnLoan(int id);

  /// Продлить выдачу на 7 дней. Читатель — только свою и только один раз.
  Future<Loan> renew(int id);
}

class ApiLoanRepository implements LoanRepository {
  final Dio _dio;
  final ApiCrud<Loan> _api;

  ApiLoanRepository(this._dio) : _api = ApiCrud(_dio, '/loans', Loan.fromJson);

  @override
  Future<PageResult<Loan>> find(
          {String? status, int page = 1, int size = 10}) =>
      _api.page({
        if (status != null) 'status': status,
        'sort': 'issuedAt,desc',
        'page': page,
        'size': size,
      });

  @override
  Future<Loan> issue(
          {required int readerId, required int bookId, int days = 14}) =>
      guard(() async {
        final response = await _dio.post<Map<String, dynamic>>('/loans',
            data: {'readerId': readerId, 'bookId': bookId, 'days': days});
        return Loan.fromJson(response.data!);
      });

  @override
  Future<Loan> renew(int id) => guard(() async {
        final response =
            await _dio.post<Map<String, dynamic>>('/loans/$id/renew');
        return Loan.fromJson(response.data!);
      });

  @override
  Future<Loan> returnLoan(int id) => guard(() async {
        final response =
            await _dio.post<Map<String, dynamic>>('/loans/$id/return');
        return Loan.fromJson(response.data!);
      });
}
