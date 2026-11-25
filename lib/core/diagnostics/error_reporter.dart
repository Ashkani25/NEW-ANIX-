import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../online/online_service.dart';
import '../update/app_updater.dart';
import '../update/build_flavor.dart';

/// Crash / error reporting (P0 #5) into the core project's `client_errors` table through `nx_log_client_error`.
///
/// Hooks: [FlutterError.onError] (framework/build/layout errors), [PlatformDispatcher.onError] (uncaught async
/// errors) and the root zone of `main` ([zoneError]). Release builds only send; debug builds just print.
/// Client-side limits on top of the server's: the same error is sent once per 10 minutes, at most 6 per minute and
/// 40 per app run; reports raised while offline wait in a small queue (20) and go out on the next report.
class ErrorReporter {
  ErrorReporter._();
  static final ErrorReporter instance = ErrorReporter._();

  static const int perMinute = 6;
  static const int perRun = 40;
  static const Duration dedupeWindow = Duration(minutes: 10);

  final Map<int, DateTime> _seen = <int, DateTime>{};
  final List<DateTime> _recent = <DateTime>[];
  final List<Map<String, dynamic>> _queue = <Map<String, dynamic>>[];
  int _sentThisRun = 0;
  bool _sending = false;

  /// Overridable for tests.
  @visibleForTesting
  bool enabled = kReleaseMode;

  static void install() {
    final FlutterExceptionHandler? previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails d) {
      if (previous != null) {
        previous(d);
      } else {
        FlutterError.presentError(d);
      }
      instance.report('flutter', d.exception, d.stack, context: <String, dynamic>{
        if (d.library != null) 'library': d.library,
        if (d.context != null) 'where': d.context.toString(),
        'silent': d.silent,
      });
    };
    PlatformDispatcher.instance.onError = (Object e, StackTrace st) {
      instance.report('platform', e, st);
      return true;
    };
  }

  /// For `runZonedGuarded(main body, ErrorReporter.zoneError)`.
  static void zoneError(Object e, StackTrace st) {
    debugPrint('uncaught: $e');
    instance.report('zone', e, st);
  }

  /// Decides whether a report may go out now (pure, unit-tested through [report]).
  @visibleForTesting
  bool admit(String key, DateTime now) {
    final int h = key.hashCode;
    final DateTime? last = _seen[h];
    if (last != null && now.difference(last) < dedupeWindow) return false;
    _recent.removeWhere((DateTime t) => now.difference(t) > const Duration(minutes: 1));
    if (_recent.length >= perMinute || _sentThisRun >= perRun) return false;
    _seen[h] = now;
    if (_seen.length > 200) _seen.remove(_seen.keys.first);
    _recent.add(now);
    _sentThisRun++;
    return true;
  }

  void report(String kind, Object error, StackTrace? stack, {Map<String, dynamic>? context}) {
    final String message = error.toString();
    final String top = (stack?.toString() ?? '').split('\n').take(3).join('\n');
    if (!admit('$kind|$message|$top', DateTime.now())) return;
    if (!enabled) return;
    _queue.add(<String, dynamic>{
      'p_kind': kind,
      'p_message': message.length > 2000 ? message.substring(0, 2000) : message,
      'p_stack': stack == null ? null : _cut(stack.toString(), 8000),
      'p_context': <String, dynamic>{...?context, 'at': DateTime.now().toUtc().toIso8601String()},
      'p_app_version': '${AppUpdater.currentVc}${BuildFlavor.isStoreBuild ? '-${BuildFlavor.store}' : ''}',
      'p_platform': _platform(),
    });
    while (_queue.length > 20) {
      _queue.removeAt(0);
    }
    unawaited(_flush());
  }

  static String _cut(String s, int n) => s.length > n ? s.substring(0, n) : s;

  static String _platform() {
    try {
      return _cut('${Platform.operatingSystem} ${Platform.operatingSystemVersion}', 60);
    } catch (_) {
      return 'unknown';
    }
  }

  Future<void> _flush() async {
    if (_sending) return;
    final OnlineService? o = OnlineService.current;
    if (o == null || o.client == null) return;
    _sending = true;
    try {
      while (_queue.isNotEmpty) {
        final Map<String, dynamic> p = _queue.first;
        try {
          await o.client!.rpc('nx_log_client_error', params: p).timeout(const Duration(seconds: 15));
          _queue.removeAt(0);
        } catch (_) {
          break; // offline: keep it for the next report
        }
      }
    } finally {
      _sending = false;
    }
  }
}
