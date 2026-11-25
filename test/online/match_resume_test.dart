import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/online/match_resume.dart';
import 'package:nexora/core/storage/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const String uid = 'user-1';
  const ActiveMatchRecord rec = ActiveMatchRecord(matchId: 'm1', gameId: 'ludo', uid: uid, tournamentMatchId: 'tm1');

  group('ActiveMatchRecord', () {
    test('round-trips through json', () {
      final ActiveMatchRecord? back = ActiveMatchRecord.fromJson(rec.toJson());
      expect(back, isNotNull);
      expect(back!.matchId, 'm1');
      expect(back.gameId, 'ludo');
      expect(back.uid, uid);
      expect(back.tournamentMatchId, 'tm1');
      expect(back.savedAt, isNotNull);
    });

    test('rejects broken json', () {
      expect(ActiveMatchRecord.fromJson(null), isNull);
      expect(ActiveMatchRecord.fromJson(<String, dynamic>{'match': 'm1'}), isNull);
      expect(ActiveMatchRecord.fromJson(<String, dynamic>{'match': '', 'game': 'ludo', 'uid': uid}), isNull);
      expect(ActiveMatchRecord.fromJson(<String, dynamic>{'match': 3, 'game': 'ludo', 'uid': uid}), isNull);
    });
  });

  group('ActiveMatchStore', () {
    late ActiveMatchStore store;
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      store = ActiveMatchStore(await LocalStore.init());
    });

    test('save / read / clear', () async {
      expect(store.read(), isNull);
      await store.save(rec);
      expect(store.read()?.matchId, 'm1');
      await store.clear();
      expect(store.read(), isNull);
    });

    test('clear(matchId) never wipes a newer match', () async {
      await store.save(rec);
      await store.clear(matchId: 'old-match');
      expect(store.read()?.matchId, 'm1');
      await store.clear(matchId: 'm1');
      expect(store.read(), isNull);
    });
  });

  group('decideResume', () {
    test('server has no live match: nothing offered, stale local record cleared', () {
      final ResumeDecision d = decideResume(local: rec, server: null, uid: uid);
      expect(d.offer, isNull);
      expect(d.clearLocal, isTrue);
      final ResumeDecision none = decideResume(local: null, server: null, uid: uid);
      expect(none.offer, isNull);
      expect(none.clearLocal, isFalse);
    });

    test('same match still live: offered with the saved tournament match', () {
      final ResumeDecision d = decideResume(
          local: rec, server: <String, dynamic>{'match_id': 'm1', 'game': 'ludo', 'tournament': true}, uid: uid);
      expect(d.offer?.matchId, 'm1');
      expect(d.offer?.gameId, 'ludo');
      expect(d.offer?.tournamentMatchId, 'tm1');
      expect(d.clearLocal, isFalse);
      expect(d.offer!.route, '/match/m1?game=ludo&t=tm1');
    });

    test('another live match (or none saved): the server match is offered, an old record is replaced', () {
      final ResumeDecision d = decideResume(
          local: rec,
          server: <String, dynamic>{'match_id': 'm2', 'game': 'uno'},
          uid: uid,
          serverTournamentMatchId: null);
      expect(d.offer?.matchId, 'm2');
      expect(d.offer?.tournamentMatchId, isNull);
      expect(d.clearLocal, isTrue);
      expect(d.offer!.route, '/match/m2?game=uno');

      final ResumeDecision fresh = decideResume(
          local: null,
          server: <String, dynamic>{'match_id': 'm3', 'game': 'backgammon'},
          uid: uid,
          serverTournamentMatchId: 'tm3');
      expect(fresh.offer?.tournamentMatchId, 'tm3');
      expect(fresh.clearLocal, isFalse);
    });

    test('a record saved by another account is never used', () {
      const ActiveMatchRecord other = ActiveMatchRecord(matchId: 'm1', gameId: 'ludo', uid: 'user-2', tournamentMatchId: 'x');
      final ResumeDecision d =
          decideResume(local: other, server: <String, dynamic>{'match_id': 'm1', 'game': 'ludo'}, uid: uid);
      expect(d.offer?.tournamentMatchId, isNull);
      expect(d.clearLocal, isTrue);
    });

    test('malformed server row counts as no live match', () {
      final ResumeDecision d = decideResume(local: rec, server: <String, dynamic>{'match_id': '', 'game': 'ludo'}, uid: uid);
      expect(d.offer, isNull);
      expect(d.clearLocal, isTrue);
    });
  });
}
