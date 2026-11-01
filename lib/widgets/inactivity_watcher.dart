import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HardwareKeyboard, KeyEvent

/// Следит за действиями пользователя во всём приложении. Через [timeout]
/// без действий вызывает [onTimeout], а за [warning] до этого показывает
/// предупреждение с обратным отсчётом.
class InactivityWatcher extends StatefulWidget {
  final bool enabled;
  final Duration timeout;
  final Duration warning;
  final VoidCallback onTimeout;
  final VoidCallback? onActivity;
  final Widget child;

  const InactivityWatcher({
    super.key,
    required this.enabled,
    required this.timeout,
    required this.warning,
    required this.onTimeout,
    this.onActivity,
    required this.child,
  });

  @override
  State<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends State<InactivityWatcher> {
  Timer? _warnTimer;
  Timer? _tick;
  int? _secondsLeft;

  @override
  void initState() {
    super.initState();
    // Клавиатуру слушаем глобально: у обёртки над приложением нет фокуса,
    // и KeyboardListener не узнал бы о наборе текста в форме
    HardwareKeyboard.instance.addHandler(_onKey);
    _restart();
  }

  @override
  void didUpdateWidget(InactivityWatcher old) {
    super.didUpdateWidget(old);
    if (old.enabled != widget.enabled) _restart();
  }

  // false — событие не обработано и идёт дальше к виджетам
  bool _onKey(KeyEvent event) {
    _activity();
    return false;
  }

  void _activity() {
    if (!widget.enabled) return;
    widget.onActivity?.call();
    _restart();
  }

  void _restart() {
    _warnTimer?.cancel();
    _tick?.cancel();
    if (_secondsLeft != null) setState(() => _secondsLeft = null);
    if (!widget.enabled) return;
    _warnTimer = Timer(widget.timeout - widget.warning, _startCountdown);
  }

  void _startCountdown() {
    setState(() => _secondsLeft = widget.warning.inSeconds);
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = (_secondsLeft ?? 0) - 1;
      if (left <= 0) {
        t.cancel();
        setState(() => _secondsLeft = null);
        widget.onTimeout();
      } else {
        setState(() => _secondsLeft = left);
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _warnTimer?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = _secondsLeft;
    return Listener(
      // Перехват без поглощения: событие идёт дальше к виджетам
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _activity(),
      onPointerMove: (_) => _activity(),
      onPointerSignal: (_) => _activity(),
      child: Stack(
        children: [
          widget.child,
          if (left != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.inverseSurface,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined,
                            color:
                                Theme.of(context).colorScheme.onInverseSurface),
                        const SizedBox(width: 12),
                        Text(
                          'Сессия завершится через $left с из-за неактивности',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onInverseSurface),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.inversePrimary,
                          ),
                          onPressed: _activity,
                          child: const Text('Продолжить работу'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
