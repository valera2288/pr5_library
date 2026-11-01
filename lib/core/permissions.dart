/// Роли пользователей (контракт API, раздел 2.2).
enum Role {
  reader('читатель'),
  librarian('библиотекарь'),
  admin('администратор');

  final String title;
  const Role(this.title);

  /// Незнакомая роль трактуется как самая безобидная: опечатка в данных
  /// не должна выдавать права администратора.
  static Role fromCode(String? code) =>
      Role.values.firstWhere((r) => r.name == code, orElse: () => Role.reader);
}

/// Операции, доступ к которым различается по ролям.
enum Permission {
  /// Просмотр каталога книг, авторов, жанров и издательств.
  viewCatalog,

  /// Свои выдачи и их продление — экран «Мои выдачи».
  viewOwnLoans,
  renewLoan,

  /// Создание, изменение и логическое удаление книг и справочников.
  manageCatalog,

  /// Оформление и закрытие выдач, список всех выдач.
  manageLoans,

  /// Список читателей и их карточки.
  manageReaders,

  /// Физическое удаление и восстановление записей.
  hardDelete,
  restore,

  /// Управление пользователями и ролями.
  manageUsers,

  /// Статистика библиотеки.
  viewStats,
}

/// Права по ролям. Наборы различаются по составу функций, а не по объёму:
/// у каждой роли есть экран, которого нет у остальных
/// («Мои выдачи», «Выдачи», «Пользователи» и «Статистика»).
const Map<Role, Set<Permission>> rolePermissions = {
  Role.reader: {
    Permission.viewCatalog,
    Permission.viewOwnLoans,
    Permission.renewLoan,
  },
  Role.librarian: {
    Permission.viewCatalog,
    Permission.manageCatalog,
    Permission.manageLoans,
    Permission.manageReaders,
  },
  Role.admin: {
    Permission.viewCatalog,
    Permission.manageCatalog,
    Permission.manageReaders,
    Permission.hardDelete,
    Permission.restore,
    Permission.manageUsers,
    Permission.viewStats,
  },
};

bool roleCan(Role? role, Permission permission) =>
    role != null && (rolePermissions[role]?.contains(permission) ?? false);
