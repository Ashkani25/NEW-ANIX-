import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../online/online_service.dart';
import 'app_updater.dart';
import 'build_flavor.dart';

/// Server-driven app gate (P0 #3): force-update below a minimum build and maintenance mode.
///
/// Reads `nx_app_status()` on the core project (public, read-only row `nx_app_config`) at start, on resume, after a
/// sign-in change and every 10 minutes. Offline or unreachable = never blocks (the app keeps working locally).
/// Admins/owner get `bypass` from the server and are never blocked by maintenance.
class AppGateStatus {
  const AppGateStatus({
    this.minVc = 0,
    this.latestVc = 0,
    this.maintenance = false,
    this.messageFa = '',
    this.messageEn = '',
    this.storeUrl = '',
    this.bypass = false,
  });

  factory AppGateStatus.fromJson(Map<dynamic, dynamic> j) => AppGateStatus(
        minVc: (j['min_version_code'] as num?)?.toInt() ?? 0,
        latestVc: (j['latest_version_code'] as num?)?.toInt() ?? 0,
        maintenance: j['maintenance'] == true,
        messageFa: '${j['message_fa'] ?? ''}',
        messageEn: '${j['message_en'] ?? ''}',
        storeUrl: '${j['store_url'] ?? ''}',
        bypass: j['bypass'] == true,
      );

  final int minVc;
  final int latestVc;
  final bool maintenance;
  final String messageFa;
  final String messageEn;
  final String storeUrl;
  final bool bypass;
}

enum AppGateBlock { none, update, maintenance }

class AppGate extends ChangeNotifier {
  AppGate._();
  static final AppGate instance = AppGate._();

  AppGateStatus? status;
  Timer? _timer;
  AppLifecycleListener? _life;
  String? _uid;
  bool _loading = false;

  /// Pure decision (unit-tested): which screen, if any, blocks a build [vc] (0 = dev build, never force-updated).
  static AppGateBlock decide(AppGateStatus? s, int vc) {
    if (s == null) return AppGateBlock.none;
    if (vc > 0 && s.minVc > 0 && vc < s.minVc) return AppGateBlock.update;
    if (s.maintenance && !s.bypass) return AppGateBlock.maintenance;
    return AppGateBlock.none;
  }

  /// Signed-out staff can hide the maintenance screen for a few minutes to reach the sign-in page; once they sign
  /// in, the server's `bypass` decides.
  DateTime? _peekUntil;
  bool get canPeek => OnlineService.current?.user == null;
  void staffPeek() {
    _peekUntil = DateTime.now().add(const Duration(minutes: 5));
    notifyListeners();
    Timer(const Duration(minutes: 5, seconds: 1), notifyListeners);
  }

  AppGateBlock get block {
    final AppGateBlock b = decide(status, AppUpdater.currentVc);
    if (b == AppGateBlock.maintenance && canPeek && _peekUntil != null && DateTime.now().isBefore(_peekUntil!)) {
      return AppGateBlock.none;
    }
    return b;
  }

  void start() {
    unawaited(refresh());
    _life ??= AppLifecycleListener(onResume: () => unawaited(refresh()));
    _timer ??= Timer.periodic(const Duration(minutes: 10), (_) => refresh());
    final OnlineService? o = OnlineService.current;
    if (o != null) {
      _uid = o.uid;
      o.addListener(() {
        if (o.uid != _uid) {
          _uid = o.uid;
          unawaited(refresh());
        }
      });
    }
  }

  bool get loading => _loading;

  Future<void> refresh() async {
    final OnlineService? o = OnlineService.current;
    if (o?.client == null || _loading) return;
    _loading = true;
    notifyListeners();
    try {
      final dynamic r = await o!.client!.rpc('nx_app_status').timeout(const Duration(seconds: 15));
      if (r is Map) status = AppGateStatus.fromJson(r);
    } catch (e) {
      debugPrint('app gate: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Opens the store page (store_url) or, for sideload builds without one, starts the in-app update.
  Future<void> openUpdate() async {
    final String configured = status?.storeUrl ?? '';
    final List<String> urls = <String>[
      if (configured.isNotEmpty) configured,
      if (BuildFlavor.isStoreBuild) BuildFlavor.defaultStoreUrl,
      if (BuildFlavor.isStoreBuild) BuildFlavor.storeWebUrl,
    ];
    for (final String url in urls) {
      if (url.isEmpty) continue;
      try {
        if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
    }
    if (AppUpdater.sideloadEnabled) {
      await AppUpdater.instance.check();
      await AppUpdater.instance.downloadAndInstall();
    }
  }
}

/// Full-screen blocker drawn above the whole app while [AppGate] says so.
class AppGateOverlay extends StatelessWidget {
  const AppGateOverlay({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppGate g = AppGate.instance;
    return ListenableBuilder(
      listenable: g,
      builder: (BuildContext context, _) {
        final AppGateBlock b = g.block;
        if (b == AppGateBlock.none) return child;
        return Stack(children: <Widget>[
          child,
          Positioned.fill(child: _GateScreen(block: b, gate: g)),
        ]);
      },
    );
  }
}

class _GateScreen extends StatelessWidget {
  const _GateScreen({required this.block, required this.gate});
  final AppGateBlock block;
  final AppGate gate;

  @override
  Widget build(BuildContext context) {
    final bool fa = Localizations.maybeLocaleOf(context)?.languageCode != 'en';
    final AppGateStatus s = gate.status ?? const AppGateStatus();
    final bool update = block == AppGateBlock.update;
    final String custom = fa ? s.messageFa : s.messageEn;
    final String title = update
        ? (fa ? 'نسخه‌ی تازه لازم است' : 'Update required')
        : (fa ? 'در حال به‌روزرسانی سرور' : 'Under maintenance');
    final String body = custom.isNotEmpty
        ? custom
        : update
            ? (fa
                ? 'این نسخه از آنیکس دیگر پشتیبانی نمی‌شود. برای ادامه، نسخه‌ی تازه را نصب کن.'
                : 'This version of ANIX is no longer supported. Install the new version to continue.')
            : (fa
                ? 'آنیکس برای مدت کوتاهی در حال نگهداری است. کمی بعد دوباره سر بزن.'
                : 'ANIX is down for a short maintenance. Please check back soon.');
    return Directionality(
      textDirection: fa ? TextDirection.rtl : TextDirection.ltr,
      child: Material(
        color: const Color(0xFF07080C),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Icon(update ? Icons.system_update_rounded : Icons.construction_rounded,
                    size: 64, color: const Color(0xFFD9B872)),
                const SizedBox(height: 18),
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Text(body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
                const SizedBox(height: 24),
                if (update)
                  ListenableBuilder(
                    listenable: AppUpdater.instance,
                    builder: (BuildContext context, _) {
                      final double? p = AppUpdater.instance.progress;
                      if (p != null) {
                        return SizedBox(
                          width: 220,
                          child: LinearProgressIndicator(value: p, color: const Color(0xFFD9B872)),
                        );
                      }
                      return FilledButton.icon(
                        key: const ValueKey<String>('gate-update'),
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD9B872), foregroundColor: Colors.black),
                        onPressed: gate.openUpdate,
                        icon: const Icon(Icons.download_rounded),
                        label: Text(fa ? 'دریافت نسخه‌ی تازه' : 'Get the update'),
                      );
                    },
                  )
                else
                  OutlinedButton.icon(
                    key: const ValueKey<String>('gate-retry'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: gate.loading ? null : gate.refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(fa ? 'دوباره بررسی کن' : 'Check again'),
                  ),
                if (!update && gate.canPeek)
                  TextButton(
                    key: const ValueKey<String>('gate-staff'),
                    onPressed: gate.staffPeek,
                    child: Text(fa ? 'ورود مدیران' : 'Staff sign-in',
                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
