import 'package:flutter_test/flutter_test.dart';

import 'package:library_app/core/permissions.dart';
import 'package:library_app/core/router.dart';

void main() {
  group('Права по ролям', () {
    test('читатель видит каталог и свои выдачи, но не управляет книгами', () {
      expect(roleCan(Role.reader, Permission.viewCatalog), isTrue);
      expect(roleCan(Role.reader, Permission.viewOwnLoans), isTrue);
      expect(roleCan(Role.reader, Permission.renewLoan), isTrue);
      expect(roleCan(Role.reader, Permission.manageCatalog), isFalse);
      expect(roleCan(Role.reader, Permission.manageLoans), isFalse);
    });

    test('библиотекарь управляет каталогом, выдачами и читателями', () {
      expect(roleCan(Role.librarian, Permission.manageCatalog), isTrue);
      expect(roleCan(Role.librarian, Permission.manageLoans), isTrue);
      expect(roleCan(Role.librarian, Permission.manageReaders), isTrue);
    });

    test(
        'библиотекарь не удаляет навсегда, не восстанавливает и не управляет ролями',
        () {
      expect(roleCan(Role.librarian, Permission.hardDelete), isFalse);
      expect(roleCan(Role.librarian, Permission.restore), isFalse);
      expect(roleCan(Role.librarian, Permission.manageUsers), isFalse);
    });

    test('администратору доступны пользователи, статистика, восстановление',
        () {
      expect(roleCan(Role.admin, Permission.manageUsers), isTrue);
      expect(roleCan(Role.admin, Permission.viewStats), isTrue);
      expect(roleCan(Role.admin, Permission.restore), isTrue);
      expect(roleCan(Role.admin, Permission.hardDelete), isTrue);
    });

    test('у каждой роли есть право, которого нет у остальных', () {
      Set<Permission> only(Role r) => rolePermissions[r]!
          .where((p) =>
              Role.values.where((o) => o != r).every((o) => !roleCan(o, p)))
          .toSet();
      expect(only(Role.reader), contains(Permission.viewOwnLoans));
      expect(only(Role.librarian), contains(Permission.manageLoans));
      expect(only(Role.admin), contains(Permission.manageUsers));
    });

    test('без входа ничего нельзя', () {
      for (final p in Permission.values) {
        expect(roleCan(null, p), isFalse);
      }
    });

    test('незнакомая роль трактуется как читатель, а не как администратор', () {
      expect(Role.fromCode('superuser'), Role.reader);
      expect(Role.fromCode(null), Role.reader);
      expect(Role.fromCode('admin'), Role.admin);
    });
  });

  group('Перенаправления маршрутизатора', () {
    test('без входа закрытый адрес ведёт на /login с параметром from', () {
      final r = authRedirect(
          loggedIn: false, uri: Uri.parse('/books/5'), matched: '/books/5');
      expect(r, '/login?from=%2Fbooks%2F5');
    });

    test('после входа возвращает на адрес из from', () {
      final r = authRedirect(
          loggedIn: true,
          uri: Uri.parse('/login?from=%2Fbooks%2F5'),
          matched: '/login');
      expect(r, '/books/5');
    });

    test('внешний адрес в from не принимается', () {
      final r = authRedirect(
          loggedIn: true,
          uri: Uri.parse('/login?from=%2F%2Fevil.example'),
          matched: '/login');
      expect(r, '/');
    });

    test('экран входа доступен без входа и не перенаправляет сам на себя', () {
      expect(
          authRedirect(
              loggedIn: false, uri: Uri.parse('/login'), matched: '/login'),
          isNull);
      expect(
          authRedirect(
              loggedIn: false,
              uri: Uri.parse('/register'),
              matched: '/register'),
          isNull);
    });
  });
}
