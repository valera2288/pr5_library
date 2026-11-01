import '../core/permissions.dart';

/// Пользователь системы (контракт, раздел 2).
class AppUser {
  final int id;
  final String username;
  final String fullName;
  final String email;
  final Role role;
  final int? readerId;

  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    this.email = '',
    required this.role,
    this.readerId,
  });

  bool can(Permission permission) => roleCan(role, permission);

  AppUser copyWith({Role? role}) => AppUser(
        id: id,
        username: username,
        fullName: fullName,
        email: email,
        role: role ?? this.role,
        readerId: readerId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'fullName': fullName,
        'email': email,
        'role': role.name,
        'readerId': readerId,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: (j['id'] as num?)?.toInt() ?? 0,
        username: (j['username'] as String?) ?? '',
        fullName: (j['fullName'] as String?) ?? '',
        email: (j['email'] as String?) ?? '',
        role: Role.fromCode(j['role'] as String?),
        readerId: (j['readerId'] as num?)?.toInt(),
      );
}
