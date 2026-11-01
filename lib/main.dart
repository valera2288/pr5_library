import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/router.dart';
import 'repositories/api/api_author_repository.dart';
import 'repositories/api/api_book_repository.dart';
import 'repositories/api/api_genre_repository.dart';
import 'repositories/api/api_publisher_repository.dart';
import 'repositories/api/api_reader_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/author_repository.dart';
import 'repositories/book_repository.dart';
import 'repositories/genre_repository.dart';
import 'repositories/loan_repository.dart';
import 'repositories/publisher_repository.dart';
import 'repositories/reader_repository.dart';
import 'state/auth_notifier.dart';
import 'state/author_list_notifier.dart';
import 'state/book_list_notifier.dart';
import 'state/genre_list_notifier.dart';
import 'state/loan_list_notifier.dart';
import 'state/publisher_list_notifier.dart';
import 'state/reader_list_notifier.dart';
import 'state/admin_notifiers.dart';
import 'state/reference_data_notifier.dart';
import 'widgets/inactivity_watcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  final prefs = await SharedPreferences.getInstance();
  final auth = AuthNotifier(prefs);
  // Единственное место, где приложение переключено с хранилища в браузере
  // на сервер: было PersistentBookRepository(prefs) и т. д.
  // При ответе 401 токен обновляется и запрос повторяется прозрачно
  final dio = buildDio(
    tokenProvider: () => auth.accessToken,
    onUnauthorized: auth.refreshTokens,
  );
  auth.repository = ApiAuthRepository(dio);
  // Сессия восстанавливается до построения дерева виджетов,
  // иначе после перезагрузки мелькнул бы экран входа
  await auth.restore();

  runApp(LibraryApp(
    auth: auth,
    bookRepository: ApiBookRepository(dio),
    authorRepository: ApiAuthorRepository(dio),
    genreRepository: ApiGenreRepository(dio),
    publisherRepository: ApiPublisherRepository(dio),
    readerRepository: ApiReaderRepository(dio),
    loanRepository: ApiLoanRepository(dio),
    userRepository: UserRepository(dio),
  ));
}

class LibraryApp extends StatefulWidget {
  final AuthNotifier auth;
  final BookRepository bookRepository;
  final AuthorRepository authorRepository;
  final GenreRepository genreRepository;
  final PublisherRepository publisherRepository;
  final ReaderRepository readerRepository;
  final LoanRepository loanRepository;
  final UserRepository userRepository;

  const LibraryApp({
    super.key,
    required this.auth,
    required this.bookRepository,
    required this.authorRepository,
    required this.genreRepository,
    required this.publisherRepository,
    required this.readerRepository,
    required this.loanRepository,
    required this.userRepository,
  });

  @override
  State<LibraryApp> createState() => _LibraryAppState();
}

class _LibraryAppState extends State<LibraryApp> {
  // Маршрутизатор создаётся один раз: его redirect читает AuthNotifier
  late final _router = buildRouter(widget.auth);

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthNotifier>.value(value: w.auth),
        Provider<BookRepository>.value(value: w.bookRepository),
        Provider<AuthorRepository>.value(value: w.authorRepository),
        Provider<GenreRepository>.value(value: w.genreRepository),
        Provider<PublisherRepository>.value(value: w.publisherRepository),
        Provider<ReaderRepository>.value(value: w.readerRepository),
        Provider<LoanRepository>.value(value: w.loanRepository),
      ],
      child: MaterialApp.router(
        title: 'Библиотека',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
          useMaterial3: true,
        ),
        routerConfig: _router,
        builder: (context, child) => ListenableBuilder(
          listenable: w.auth,
          builder: (context, _) => KeyedSubtree(
            // Состояние списков принадлежит пользователю: при входе и выходе
            // оно создаётся заново, и следующий пользователь не увидит
            // чужие данные и настройки (например, переключатель «Удалённые»)
            key: ValueKey(w.auth.user?.id),
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider(
                  create: (_) => UsersNotifier(w.userRepository),
                ),
                ChangeNotifierProvider(
                  create: (c) => StatsNotifier(
                    c.read<BookRepository>(),
                    c.read<AuthorRepository>(),
                    c.read<ReaderRepository>(),
                    c.read<LoanRepository>(),
                  ),
                ),
                // Справочники (жанры, издательства, авторы) запрашиваются
                // один раз и не перезагружаются при каждом открытии формы
                ChangeNotifierProvider(
                  create: (c) => ReferenceDataNotifier(
                    c.read<GenreRepository>(),
                    c.read<PublisherRepository>(),
                    c.read<AuthorRepository>(),
                  ),
                ),
                ChangeNotifierProvider(
                  create: (c) => BookListNotifier(c.read<BookRepository>()),
                ),
                ChangeNotifierProvider(
                  create: (c) => AuthorListNotifier(c.read<AuthorRepository>()),
                ),
                ChangeNotifierProvider(
                  create: (c) => GenreListNotifier(c.read<GenreRepository>()),
                ),
                ChangeNotifierProvider(
                  create: (c) =>
                      PublisherListNotifier(c.read<PublisherRepository>()),
                ),
                ChangeNotifierProvider(
                  create: (c) => ReaderListNotifier(c.read<ReaderRepository>()),
                ),
                ChangeNotifierProvider(
                  create: (c) => LoanListNotifier(
                    c.read<LoanRepository>(),
                    c.read<ReaderRepository>(),
                    c.read<BookRepository>(),
                  ),
                ),
              ],
              // Неактивность отслеживается над всеми экранами сразу
              child: InactivityWatcher(
                enabled: w.auth.isAuthenticated,
                timeout: AuthNotifier.inactivityTimeout,
                warning: AuthNotifier.inactivityWarning,
                onActivity: w.auth.markActivity,
                onTimeout: () => w.auth
                    .logout(reason: 'Сессия завершена из-за неактивности.'),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
