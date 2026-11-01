import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../screens/admin/stats_screen.dart';
import '../screens/admin/users_screen.dart';
import '../screens/authors/author_detail_screen.dart';
import '../screens/authors/author_form_screen.dart';
import '../screens/authors/author_list_screen.dart';
import '../screens/books/book_detail_screen.dart';
import '../screens/books/book_form_screen.dart';
import '../screens/books/book_list_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/forbidden_screen.dart';
import '../screens/genres/genre_detail_screen.dart';
import '../screens/genres/genre_form_screen.dart';
import '../screens/genres/genre_list_screen.dart';
import '../screens/loans/loan_list_screen.dart';
import '../screens/loans/my_loans_screen.dart';
import '../screens/login_screen.dart';
import '../screens/not_found_screen.dart';
import '../screens/publishers/publisher_detail_screen.dart';
import '../screens/publishers/publisher_form_screen.dart';
import '../screens/publishers/publisher_list_screen.dart';
import '../screens/readers/reader_detail_screen.dart';
import '../screens/readers/reader_form_screen.dart';
import '../screens/readers/reader_list_screen.dart';
import '../screens/register_screen.dart';
import '../state/auth_notifier.dart';
import 'permissions.dart';

/// Публичные адреса — доступны без входа.
const publicPaths = {'/login', '/register'};

/// Решение общего redirect: куда отправить пользователя или null,
/// если переход разрешён. Вынесено отдельно, чтобы проверить тестами.
String? authRedirect(
    {required bool loggedIn, required Uri uri, required String matched}) {
  final isPublic = publicPaths.contains(matched);
  // Не вошёл и идёт на закрытый экран — на вход, запомнив адрес
  if (!loggedIn && !isPublic) {
    final from = uri.toString();
    return from == '/' ? '/login' : '/login?from=${Uri.encodeComponent(from)}';
  }
  // Уже вошёл и стоит на экране входа: возвращаем туда, откуда его
  // перенаправили, иначе на главную. Принимаются только внутренние адреса,
  // чтобы ссылкой вида ?from=//evil.example нельзя было увести на чужой сайт.
  if (loggedIn && isPublic) {
    final from = uri.queryParameters['from'];
    final safe = from != null &&
        from.startsWith('/') &&
        !from.startsWith('//') &&
        !from.startsWith('/login');
    return safe ? from : '/';
  }
  return null;
}

int _id(GoRouterState s) => int.tryParse(s.pathParameters['id'] ?? '') ?? -1;

GoRouter buildRouter(AuthNotifier auth) {
  /// Проверка роли на уровне ветки маршрутов. Срабатывает до построения
  /// экрана, поэтому экран отказа не мелькает и не исчезает.
  GoRouterRedirect need(Permission p) =>
      (BuildContext c, GoRouterState s) => auth.can(p) ? null : '/forbidden';

  GoRoute crud({
    required String path,
    required Widget list,
    required Widget Function() create,
    required Widget Function(int id) detail,
    required Widget Function(int id) edit,
    required Permission view,
    required Permission manage,
  }) =>
      GoRoute(
        path: path,
        redirect: need(view),
        pageBuilder: (c, s) => NoTransitionPage(child: list),
        routes: [
          GoRoute(
              path: 'new', redirect: need(manage), builder: (c, s) => create()),
          GoRoute(path: ':id', builder: (c, s) => detail(_id(s))),
          GoRoute(
              path: ':id/edit',
              redirect: need(manage),
              builder: (c, s) => edit(_id(s))),
        ],
      );

  return GoRouter(
    // Маршрутизатор пересчитывает redirect при каждом notifyListeners():
    // после входа уходит с формы, после выхода возвращается на неё
    refreshListenable: auth,
    initialLocation: '/',
    redirect: (context, state) => authRedirect(
      loggedIn: auth.isAuthenticated,
      uri: state.uri,
      matched: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: '/login',
        builder: (c, s) => LoginScreen(from: s.uri.queryParameters['from']),
      ),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(
        path: '/',
        pageBuilder: (c, s) => const NoTransitionPage(child: DashboardScreen()),
      ),
      crud(
        path: '/books',
        list: const BookListScreen(),
        create: () => const BookFormScreen(),
        detail: (id) => BookDetailScreen(id: id),
        edit: (id) => BookFormScreen(id: id),
        view: Permission.viewCatalog,
        manage: Permission.manageCatalog,
      ),
      crud(
        path: '/authors',
        list: const AuthorListScreen(),
        create: () => const AuthorFormScreen(),
        detail: (id) => AuthorDetailScreen(id: id),
        edit: (id) => AuthorFormScreen(id: id),
        view: Permission.viewCatalog,
        manage: Permission.manageCatalog,
      ),
      crud(
        path: '/genres',
        list: const GenreListScreen(),
        create: () => const GenreFormScreen(),
        detail: (id) => GenreDetailScreen(id: id),
        edit: (id) => GenreFormScreen(id: id),
        view: Permission.viewCatalog,
        manage: Permission.manageCatalog,
      ),
      crud(
        path: '/publishers',
        list: const PublisherListScreen(),
        create: () => const PublisherFormScreen(),
        detail: (id) => PublisherDetailScreen(id: id),
        edit: (id) => PublisherFormScreen(id: id),
        view: Permission.viewCatalog,
        manage: Permission.manageCatalog,
      ),
      crud(
        path: '/readers',
        list: const ReaderListScreen(),
        create: () => const ReaderFormScreen(),
        detail: (id) => ReaderDetailScreen(id: id),
        edit: (id) => ReaderFormScreen(id: id),
        view: Permission.manageReaders,
        manage: Permission.manageReaders,
      ),
      GoRoute(
        path: '/loans',
        redirect: need(Permission.manageLoans),
        pageBuilder: (c, s) => const NoTransitionPage(child: LoanListScreen()),
      ),
      GoRoute(
        path: '/my-loans',
        redirect: need(Permission.viewOwnLoans),
        pageBuilder: (c, s) => const NoTransitionPage(child: MyLoansScreen()),
      ),
      GoRoute(
        path: '/admin/users',
        redirect: need(Permission.manageUsers),
        pageBuilder: (c, s) => const NoTransitionPage(child: UsersScreen()),
      ),
      GoRoute(
        path: '/admin/stats',
        redirect: need(Permission.viewStats),
        pageBuilder: (c, s) => const NoTransitionPage(child: StatsScreen()),
      ),
      GoRoute(path: '/forbidden', builder: (c, s) => const ForbiddenScreen()),
    ],
    errorBuilder: (c, s) => NotFoundScreen(location: s.uri.toString()),
  );
}
