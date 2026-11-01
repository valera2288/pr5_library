import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_exceptions.dart';
import '../core/permissions.dart';
import '../models/app_user.dart';
import '../repositories/auth_repository.dart';

/// Сессия пользователя: токены, текущий пользователь и сроки жизни сессии.
///
/// Роль здесь нужна только для того, чтобы нарисовать интерфейс. Решение
/// «разрешить операцию» принимает сервер по подписанному токену.
class AuthNotifier extends ChangeNotifier {
  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';
  static const _kUser = 'auth_user';
  static const _kLoginAt = 'auth_login_at';
  static const _kLastActivity = 'auth_last_activity';

  /// Без действий пользователя сессия завершается через 3 минуты.
  static const inactivityTimeout = Duration(minutes: 3);

  /// Предупреждение показывается за 30 секунд до выхода.
  static const inactivityWarning = Duration(seconds: 30);

  /// Общая длительность сессии независимо от активности.
  /// Задаётся при сборке: --dart-define=SESSION_MAX_MINUTES=60
  static const sessionMax = Duration(
      minutes: int.fromEnvironment('SESSION_MAX_MINUTES', defaultValue: 120));

  final SharedPreferences _prefs;
  AuthRepository? _repository;

  AuthNotifier(this._prefs);

  /// Репозиторий задаётся после создания: ему нужен Dio,
  /// а Dio берёт токен отсюда.
  set repository(AuthRepository value) => _repository = value;

  String? _accessToken;
  String? _refreshToken;
  AppUser? _user;
  DateTime? _loginAt;
  Timer? _sessionTimer;
  Future<bool>? _refreshing;
  String? _endReason;
  DateTime _lastActivitySaved = DateTime.fromMillisecondsSinceEpoch(0);

  AppUser? get user => _user;
  String? get accessToken => _accessToken;
  bool get isAuthenticated => _user != null && _accessToken != null;
  Role? get role => _user?.role;

  bool can(Permission permission) => _user?.can(permission) ?? false;

  /// Почему сессия завершилась — показывается на экране входа один раз.
  String? takeEndReason() {
    final reason = _endReason;
    _endReason = null;
    return reason;
  }

  /// Восстановление сессии при запуске, до построения дерева виджетов.
  Future<void> restore() async {
    final access = _prefs.getString(_kAccess);
    if (access == null) return;
    _accessToken = access;
    _refreshToken = _prefs.getString(_kRefresh);
    _loginAt = DateTime.tryParse(_prefs.getString(_kLoginAt) ?? '');

    // Сроки сессии проверяются и через перезагрузку страницы
    final now = DateTime.now();
    final last = DateTime.tryParse(_prefs.getString(_kLastActivity) ?? '');
    if (last != null && now.difference(last) > inactivityTimeout) {
      await logout(reason: 'Сессия завершена из-за неактивности.');
      return;
    }
    // Время входа пропало (очищено или повреждено): отсчёт идёт заново,
    // иначе предел длительности сессии для такой записи не действовал бы
    if (_loginAt == null) {
      _loginAt = now;
      await _prefs.setString(_kLoginAt, now.toIso8601String());
    }
    if (now.difference(_loginAt!) > sessionMax) {
      await logout(reason: 'Истёк максимальный срок сессии. Войдите снова.');
      return;
    }

    // Профиль хранится в браузере, чтобы сразу нарисовать интерфейс.
    // Он не даёт никаких прав: сервер проверяет роль по токену.
    _user = _readCachedUser();
    if (_user == null) {
      try {
        _user = await _repository!.me();
        await _saveUser();
      } on UnauthorizedException {
        if (!await refreshTokens()) return;
      } on ApiException {
        // Сервер недоступен: сессию не сбрасываем, ошибку покажут экраны
      }
    }
    _startSessionTimer();
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final result = await _repository!.login(username, password);
    _loginAt = DateTime.now();
    await _prefs.setString(_kLoginAt, _loginAt!.toIso8601String());
    await _apply(result);
    markActivity(force: true);
    _startSessionTimer();
    notifyListeners();
  }

  /// Регистрация и сразу вход под новой учётной записью.
  Future<void> register({
    required String username,
    required String password,
    required String email,
    required String fullName,
  }) async {
    await _repository!.register(
        username: username,
        password: password,
        email: email,
        fullName: fullName);
    await login(username, password);
  }

  /// Обновление пары токенов. Одновременные 401 от нескольких запросов
  /// ждут одно и то же обновление, а не запускают по своему.
  /// Возвращает false, если обновить не удалось — тогда сессия завершена.
  Future<bool> refreshTokens() => _refreshing ??= _doRefresh().whenComplete(() {
        _refreshing = null;
      });

  Future<bool> _doRefresh() async {
    final token = _refreshToken;
    if (token == null) {
      await logout(reason: 'Сессия истекла. Войдите снова.');
      return false;
    }
    try {
      // Роль после обновления берётся из ответа сервера
      await _apply(await _repository!.refresh(token));
      notifyListeners();
      return true;
    } on ApiException {
      await logout(reason: 'Сессия истекла. Войдите снова.');
      return false;
    }
  }

  Future<void> logout({String? reason}) async {
    final refresh = _refreshToken;
    if (refresh != null && _repository != null) {
      // Аннулируем токен обновления на сервере; ошибка сети выходу не мешает
      unawaited(_repository!.logout(refresh).catchError((Object _) {}));
    }
    _sessionTimer?.cancel();
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    _loginAt = null;
    _endReason = reason;
    for (final k in [_kAccess, _kRefresh, _kUser, _kLoginAt, _kLastActivity]) {
      await _prefs.remove(k);
    }
    notifyListeners();
  }

  /// Отметка о действии пользователя. Пишется в localStorage не чаще
  /// раза в 5 секунд — по ней неактивность считается и после перезагрузки.
  void markActivity({bool force = false}) {
    if (!isAuthenticated && !force) return;
    final now = DateTime.now();
    if (!force &&
        now.difference(_lastActivitySaved) < const Duration(seconds: 5)) {
      return;
    }
    _lastActivitySaved = now;
    _prefs.setString(_kLastActivity, now.toIso8601String());
  }

  Future<void> _apply(AuthResult result) async {
    _accessToken = result.accessToken;
    _refreshToken = result.refreshToken;
    _user = result.user;
    await _prefs.setString(_kAccess, result.accessToken);
    await _prefs.setString(_kRefresh, result.refreshToken);
    await _saveUser();
  }

  Future<void> _saveUser() async {
    final u = _user;
    if (u != null) await _prefs.setString(_kUser, jsonEncode(u.toJson()));
  }

  AppUser? _readCachedUser() {
    final raw = _prefs.getString(_kUser);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    final start = _loginAt;
    if (start == null) return;
    final left = sessionMax - DateTime.now().difference(start);
    _sessionTimer = Timer(left.isNegative ? Duration.zero : left, () {
      logout(reason: 'Истёк максимальный срок сессии. Войдите снова.');
    });
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }
}
