import 'dart:async';

import 'package:flutter/foundation.dart';

import 'net_link.dart';

/// Keeps a server-authoritative game (mafia, spy_mafia, uno) in sync with this phone's view.
///
/// The server is the only source of truth: it deals, checks every input (`nx_hg_act`), resolves phases and turns,
/// applies timeouts and decides the winner. This phone only ever learns what its own player may know: its view is
/// re-read when the public move log moves (the server appends a hint row for every public change) and on a short
/// poll (private changes such as a night action or the Mafia chat add no public row). When the server deadline has
/// passed, any phone may ask the server to apply the timeout (`{a: 'tick'}`); the server refuses an early tick.
class ServerGameSync {
  ServerGameSync(this.net, {required this.onView, this.poll = const Duration(seconds: 2)});

  final NetLink net;
  final void Function(Map<String, dynamic> view) onView;
  final Duration poll;

  Timer? _timer;
  bool _busy = false;
  bool _again = false;
  bool _closed = false;
  int _ver = -1;
  Duration _skew = Duration.zero;
  DateTime? _lastTick;
  Map<String, dynamic>? _last;

  ServerGameLink? get _link => net is ServerGameLink ? net as ServerGameLink : null;

  /// Latest view (null until the first one arrived).
  Map<String, dynamic>? get view => _last;

  /// Server deadline of the current phase / turn, null when none.
  DateTime? get deadline => DateTime.tryParse('${_last?['deadline'] ?? ''}');

  /// Time left until [deadline] on the server clock (null when there is no deadline).
  Duration? get remaining {
    final DateTime? d = deadline;
    if (d == null) return null;
    final Duration r = d.difference(DateTime.now().toUtc().add(_skew));
    return r.isNegative ? Duration.zero : r;
  }

  void start() {
    net.listen((NetMove _) => unawaited(refresh()), onReplayDone: () => unawaited(refresh()));
    _timer = Timer.periodic(poll, (_) {
      unawaited(refresh());
      _maybeTick();
    });
    unawaited(refresh());
  }

  Future<void> refresh() async {
    final ServerGameLink? l = _link;
    if (l == null || _closed) return;
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      do {
        _again = false;
        final Map<String, dynamic>? v = await l.readView();
        if (_closed) return;
        if (v == null) continue;
        final DateTime? sn = DateTime.tryParse('${v['server_now'] ?? ''}');
        if (sn != null) _skew = sn.toUtc().difference(DateTime.now().toUtc());
        final int ver = (v['ver'] as num?)?.toInt() ?? 0;
        if (ver > _ver) {
          _ver = ver;
          _last = v;
          onView(v);
        }
      } while (_again && !_closed);
    } catch (e) {
      debugPrint('server view refresh failed: $e');
    } finally {
      _busy = false;
    }
  }

  void _maybeTick() {
    final DateTime? d = deadline;
    if (d == null || _closed) return;
    final DateTime now = DateTime.now().toUtc();
    if (now.add(_skew).isBefore(d.add(const Duration(seconds: 1)))) return;
    if (_lastTick != null && now.difference(_lastTick!) < const Duration(seconds: 4)) return;
    _lastTick = now;
    unawaited(act(<String, dynamic>{'a': 'tick'}));
  }

  /// Sends one input; the new view follows (refresh) whatever the answer.
  Future<Map<String, dynamic>> act(Map<String, dynamic> action) async {
    final ServerGameLink? l = _link;
    if (l == null || _closed) return <String, dynamic>{'ok': false, 'reason': 'offline'};
    try {
      final Map<String, dynamic> r = await l.act(action);
      unawaited(refresh());
      return r;
    } catch (e) {
      debugPrint('server act ${action['a']} failed: $e');
      unawaited(refresh());
      return <String, dynamic>{'ok': false, 'reason': 'error'};
    }
  }

  void dispose() {
    _closed = true;
    _timer?.cancel();
  }
}

/// Small typed readers for server views.
int? vInt(dynamic v) => v is num ? v.toInt() : null;
List<int> vInts(dynamic v) => v is List ? <int>[for (final dynamic e in v) if (e is num) e.toInt()] : <int>[];
List<Map<String, dynamic>> vMaps(dynamic v) =>
    v is List ? <Map<String, dynamic>>[for (final dynamic e in v) if (e is Map) Map<String, dynamic>.from(e)] : <Map<String, dynamic>>[];
