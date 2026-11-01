import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:library_app/core/api_client.dart';
import 'package:library_app/main.dart';
import 'package:library_app/repositories/api/api_author_repository.dart';
import 'package:library_app/repositories/api/api_book_repository.dart';
import 'package:library_app/repositories/api/api_genre_repository.dart';
import 'package:library_app/repositories/api/api_publisher_repository.dart';
import 'package:library_app/repositories/api/api_reader_repository.dart';
import 'package:library_app/repositories/auth_repository.dart';
import 'package:library_app/repositories/loan_repository.dart';
import 'package:library_app/state/auth_notifier.dart';

import 'fake_adapter.dart';

void main() {
  testWidgets('Без входа приложение открывает экран входа',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dio = buildDio(baseUrl: 'http://test/api')
      ..httpClientAdapter = FakeAdapter((_) => (200, pageOf([])));

    await tester.pumpWidget(LibraryApp(
      auth: AuthNotifier(prefs),
      bookRepository: ApiBookRepository(dio),
      authorRepository: ApiAuthorRepository(dio),
      genreRepository: ApiGenreRepository(dio),
      publisherRepository: ApiPublisherRepository(dio),
      readerRepository: ApiReaderRepository(dio),
      loanRepository: ApiLoanRepository(dio),
      userRepository: UserRepository(dio),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Закрытые экраны недоступны без входа: redirect ведёт на /login
    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Каталог книг'), findsNothing);
  });
}
