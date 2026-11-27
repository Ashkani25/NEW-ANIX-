import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_poolakey/flutter_poolakey.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../online/online_config.dart';
import '../online/online_service.dart';
import '../profile/profile_service.dart';

/// RSA public key of the app's in-app billing (Bazaar Pishkhan -> app -> پرداخت درون‌برنامه‌ای -> RSA).
/// Passed at build time: --dart-define=BAZAAR_RSA_KEY=...  Empty = the store tab shows "not available".
const String kBazaarRsaKey = String.fromEnvironment('BAZAAR_RSA_KEY');

/// A coin / gem pack sold for rials through Cafe Bazaar (row of public.nx_iap_products).
class IapPack {
  const IapPack({
    required this.sku,
    required this.coins,
    required this.gems,
    required this.priceToman,
    required this.titleFa,
    required this.titleEn,
    this.badgeFa,
  });

  factory IapPack.fromRow(Map<String, dynamic> m) => IapPack(
        sku: '${m['sku']}',
        coins: (m['coins'] as num?)?.toInt() ?? 0,
        gems: (m['gems'] as num?)?.toInt() ?? 0,
        priceToman: (m['price_toman'] as num?)?.toInt() ?? 0,
        titleFa: '${m['title_fa'] ?? ''}',
        titleEn: '${m['title_en'] ?? ''}',
        badgeFa: m['badge_fa'] as String?,
      );

  final String sku;
  final int coins;
  final int gems;
  final int priceToman;
  final String titleFa;
  final String titleEn;
  final String? badgeFa;
}

/// Result of a pack purchase.
class IapResult {
  const IapResult(this.ok, {this.error, this.grantedCoins = 0, this.grantedGems = 0});
  final bool ok;
  final String? error; // cancelled | not_configured | bazaar_missing | offline | account_required | verify | ...
  final int grantedCoins;
  final int grantedGems;
}

/// Cafe Bazaar in-app billing (Poolakey). Buying a pack: Bazaar purchase (payload = uid) -> server verification
/// (Edge Function nx-bazaar-verify, which also credits the wallet) -> consume. A purchase that was paid but not
/// verified yet (network drop, app killed) stays unconsumed in Bazaar and is finished by [recoverPending].
class BazaarStore extends ChangeNotifier {
  BazaarStore._();
  static final BazaarStore instance = BazaarStore._();

  final List<IapPack> packs = <IapPack>[];
  bool loaded = false;
  bool busy = false;
  bool _connected = false;
  Completer<bool>? _connecting;

  bool get configured => kBazaarRsaKey.isNotEmpty && defaultTargetPlatform == TargetPlatform.android && !kIsWeb;

  SupabaseClient? get _c {
    final SupabaseClient? c = OnlineService.current?.client;
    if (c == null || c.auth.currentSession == null) return null;
    return c;
  }

  /// Loads the active packs (readable without signing in).
  Future<void> load() async {
    final SupabaseClient? c = OnlineService.current?.client;
    if (c == null) return;
    try {
      final List<dynamic> rows = await c.from('nx_iap_products').select().eq('active', true).order('sort');
      packs
        ..clear()
        ..addAll(rows.map((dynamic e) => IapPack.fromRow(Map<String, dynamic>.from(e as Map))));
      loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('nx_iap_products: $e');
    }
  }

  Future<bool> _connect() async {
    if (!configured) return false;
    if (_connected) return true;
    final Completer<bool>? pending = _connecting;
    if (pending != null) return pending.future;
    final Completer<bool> done = Completer<bool>();
    _connecting = done;
    try {
      await FlutterPoolakey.connect(kBazaarRsaKey,
          onSucceed: () {
            _connected = true;
            if (!done.isCompleted) done.complete(true);
          },
          onFailed: () {
            if (!done.isCompleted) done.complete(false);
          },
          onDisconnected: () => _connected = false);
    } catch (e) {
      debugPrint('poolakey connect: $e');
      if (!done.isCompleted) done.complete(false);
    }
    final bool ok = await done.future.timeout(const Duration(seconds: 15), onTimeout: () => false);
    _connecting = null;
    return ok;
  }

  Future<Map<String, dynamic>?> _verify(SupabaseClient c, PurchaseInfo p) async {
    try {
      final FunctionResponse r = await c.functions.invoke('nx-bazaar-verify',
          body: <String, dynamic>{
            'sku': p.productId,
            'purchase_token': p.purchaseToken,
            'order_id': p.orderId,
            'purchase_time': p.purchaseTime,
          },
          region: OnlineConfig.functionsRegion.isEmpty ? null : OnlineConfig.functionsRegion);
      final dynamic d = r.data;
      return d is Map ? Map<String, dynamic>.from(d) : null;
    } on FunctionException catch (e) {
      final dynamic d = e.details;
      return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{'ok': false, 'error': 'verify', 'retry': true};
    } catch (e) {
      debugPrint('nx-bazaar-verify: $e');
      return <String, dynamic>{'ok': false, 'error': 'network', 'retry': true};
    }
  }

  void _applyWallet(Map<String, dynamic> r) {
    ProfileService.current?.applyWallet(
        xp: (r['xp'] as num?)?.toInt(), coins: (r['coins'] as num?)?.toInt(), gems: (r['gems'] as num?)?.toInt());
  }

  /// Verifies and consumes one paid purchase. Returns the server answer (null = keep it for a later retry).
  Future<Map<String, dynamic>?> _finish(SupabaseClient c, PurchaseInfo p) async {
    final Map<String, dynamic>? r = await _verify(c, p);
    if (r == null) return null;
    if (r['ok'] == true) {
      _applyWallet(r);
      try {
        await FlutterPoolakey.consume(p.purchaseToken);
      } catch (e) {
        debugPrint('poolakey consume: $e'); // the server already recorded the token; a later consume is harmless
      }
      return r;
    }
    if (r['retry'] == true) return null; // store or server hiccup: leave it unconsumed
    return r;
  }

  Future<IapResult> buy(IapPack pack) async {
    if (!configured) return const IapResult(false, error: 'not_configured');
    final SupabaseClient? c = _c;
    final String? uid = OnlineService.current?.uid;
    if (c == null || uid == null) return const IapResult(false, error: 'offline');
    if (c.auth.currentUser?.isAnonymous ?? false) return const IapResult(false, error: 'account_required');
    if (busy) return const IapResult(false, error: 'busy');
    busy = true;
    notifyListeners();
    try {
      if (!await _connect()) return const IapResult(false, error: 'bazaar_missing');
      final PurchaseInfo p;
      try {
        p = await FlutterPoolakey.purchase(pack.sku, payload: uid);
      } on PlatformException catch (e) {
        final String m = '${e.code} ${e.message}'.toLowerCase();
        return IapResult(false, error: m.contains('cancel') ? 'cancelled' : 'purchase');
      }
      final Map<String, dynamic>? r = await _finish(c, p);
      if (r == null) return const IapResult(false, error: 'pending');
      if (r['ok'] != true) return IapResult(false, error: '${r['error'] ?? 'verify'}');
      return IapResult(true,
          grantedCoins: (r['granted_coins'] as num?)?.toInt() ?? 0,
          grantedGems: (r['granted_gems'] as num?)?.toInt() ?? 0);
    } catch (e) {
      debugPrint('bazaar buy: $e');
      return const IapResult(false, error: 'purchase');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Finishes purchases that were paid but never verified / consumed (call after sign-in).
  Future<void> recoverPending() async {
    if (!configured) return;
    final SupabaseClient? c = _c;
    if (c == null || (c.auth.currentUser?.isAnonymous ?? false)) return;
    try {
      if (!await _connect()) return;
      final List<PurchaseInfo> owned = await FlutterPoolakey.getAllPurchasedProducts();
      final String? uid = OnlineService.current?.uid;
      for (final PurchaseInfo p in owned) {
        if (p.payload.isNotEmpty && p.payload != uid) continue; // bought on another ANIX account on this phone
        await _finish(c, p);
      }
    } catch (e) {
      debugPrint('bazaar recover: $e');
    }
  }
}

/// Persian / English text for a store error.
String iapErrorText(String? e, bool fa) => switch (e) {
      'cancelled' => fa ? 'خرید لغو شد' : 'Purchase cancelled',
      'not_configured' => fa ? 'خرید فعلاً در دسترس نیست' : 'The store is not available yet',
      'bazaar_missing' => fa ? 'برای خرید، کافه‌بازار را نصب و وارد حسابت شو' : 'Install Cafe Bazaar and sign in to buy',
      'offline' => fa ? 'برای خرید وارد حساب شو (آنلاین)' : 'Sign in (online) to buy',
      'account_required' => fa ? 'برای خرید باید حساب کاربری بسازی' : 'Create an account to buy',
      'pending' => fa
          ? 'پرداخت انجام شد ولی تأیید نشد؛ دفعه‌ی بعد که وارد شوی خودکار اضافه می‌شود'
          : 'Paid but not confirmed yet; it will be added automatically next time',
      'payload_mismatch' || 'token_used' => fa ? 'این خرید مال حساب دیگری است' : 'This purchase belongs to another account',
      _ => fa ? 'خرید انجام نشد' : 'Purchase failed',
    };
