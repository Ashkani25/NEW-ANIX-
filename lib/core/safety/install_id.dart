import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A random id for this app install (P0 #7c, ban evasion hold).
///
/// It is NOT a hardware or advertising id: 32 random hex characters created on first use and kept in the app's
/// preferences, so reinstalling the app or clearing its data makes a new one. It is only sent to the server when
/// signing up, signing in and deleting the account; the server keeps nothing but a keyed hash of it, and only when a
/// banned account is deleted (see supabase/migrations/20261125210200_p0_07c_ban_hold.sql).
class InstallId {
  InstallId._();

  static const String _key = 'nx.install.id';
  static String? _cached;

  /// Same shape the server accepts (`^[a-z0-9-]{16,80}$`).
  static final RegExp pattern = RegExp(r'^[a-z0-9-]{16,80}$');

  @visibleForTesting
  static String generate([Random? random]) {
    final Random r = random ?? Random.secure();
    const String hex = '0123456789abcdef';
    return List<String>.generate(32, (_) => hex[r.nextInt(16)]).join();
  }

  /// This install's id (created on first call). Null only if preferences are unavailable.
  static Future<String?> get() async {
    if (_cached != null) return _cached;
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      String? id = p.getString(_key);
      if (id == null || !pattern.hasMatch(id)) {
        id = generate();
        await p.setString(_key, id);
      }
      return _cached = id;
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static void resetCache() => _cached = null;
}
