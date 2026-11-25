// Finger soccer v13 (owner request 2026-11-24, "بازی مجدد"): rematch at the end of an ONLINE match.
//
// Since 2026-11-26 the rematch itself (state machine, controller, panel, server calls) is the generic one every online
// game uses: lib/core/online/match_rematch.dart. Finger soccer keeps:
//   * its own live event 'fs_rm' (phones on an older build still understand each other),
//   * the rematch strip on its end-of-match score table (bm_view.dart), and
//   * [FsRematchCarry]: each phone's team / formation (and the host's pitch / ball) carried into the new match, so it
//     starts with the same teams and a 0-0 score without the pick screens.
// The old Fs* names stay as aliases so callers and tests keep working.
import 'package:flutter/foundation.dart';

import 'package:nexora/core/online/match_rematch.dart';
import 'package:nexora/games/core/net_link.dart';

export 'package:nexora/core/online/match_rematch.dart';

/// Live event name of every finger-soccer rematch message.
const String kFsRematchEvent = 'fs_rm';

/// How long a request waits for an answer (ms).
const int kFsRematchTimeoutMs = kRematchTimeoutMs;

/// How long the new match may take to appear once everyone accepted (ms).
const int kFsRematchStartMs = kRematchStartMs;

typedef FsRematchPhase = RematchPhase;
typedef FsRematchMachine = RematchMachine;
typedef FsRematchStarter = RematchStarter;
typedef FsRematchRoomPoll = RematchRoomPoll;
typedef FsRematchPanel = MatchRematchPanel;

/// The generic controller on the finger-soccer event.
class FsRematchController extends MatchRematchController {
  FsRematchController({
    required super.net,
    required super.starter,
    required super.roomPoll,
    required super.onGo,
    super.clock,
    super.rnd,
  }) : super(event: kFsRematchEvent);

  /// A controller for a live Supabase match, or null when a rematch is not offered (tournament game, no room).
  static MatchRematchController? forLink(NetLink? net,
          {required String? tournamentMatchId, required void Function(String) onGo}) =>
      MatchRematchController.forLink(net, tournamentMatchId: tournamentMatchId, onGo: onGo, event: kFsRematchEvent);
}

/// A rematch is offered for room matches that are not tournament games.
bool fsRematchAllowed(Map<String, dynamic> settings, {required String? roomId}) =>
    matchRematchAllowed(settings, roomId: roomId);

/// The team / formation (and the host's pitch / ball) a phone carries into the rematch, read by the new match's view.
class FsRematchCarry {
  FsRematchCarry._(this.fromMatch, this.names, this.setup, this.at);
  final String fromMatch;
  final List<String> names;

  /// This phone's own setup move ({'a': 'setup', team, form, field, ball}).
  final Map<String, dynamic> setup;
  final DateTime at;

  static FsRematchCarry? _pending;

  static void put(String fromMatch, List<String> names, Map<String, dynamic> setup) =>
      _pending = FsRematchCarry._(fromMatch, List<String>.from(names), Map<String, dynamic>.from(setup), DateTime.now());

  /// The carried setup for a newly opened match with the same players (once; null when there is none).
  static Map<String, dynamic>? take(NetLink net) {
    final FsRematchCarry? c = _pending;
    if (c == null) return null;
    if (DateTime.now().difference(c.at) > const Duration(minutes: 2)) {
      _pending = null;
      return null;
    }
    if (net.matchId == c.fromMatch || !_same(net.names, c.names)) return null;
    _pending = null;
    return c.setup;
  }

  static bool _same(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @visibleForTesting
  static void clear() => _pending = null;
}

