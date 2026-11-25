import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/economy/bazaar_store.dart';
import 'package:nexora/core/economy/wallet_ledger.dart';

void main() {
  test('ledger rows parse from the nx_wallet_history answer', () {
    final List<WalletLedgerEntry> rows = parseWalletHistory(<Object?>[
      <String, dynamic>{'id': 3, 'currency': 'gems', 'delta': -150, 'balance_after': 200, 'reason': 'shop:gems',
        'ref': 'fs_team:lux0', 'created_at': '2026-11-25T20:00:00+00:00'},
      <String, dynamic>{'id': 7, 'currency': 'coins', 'delta': 60, 'balance_after': 636, 'reason': 'award:daily'},
      <String, dynamic>{'id': 1, 'currency': 'coins', 'delta': 576, 'balance_after': 576, 'reason': 'opening_balance'},
      <String, dynamic>{'id': 9, 'currency': 'diamonds', 'delta': 1, 'balance_after': 1, 'reason': 'x'}, // unknown currency
      'garbage',
    ]);
    expect(rows.map((WalletLedgerEntry e) => e.id).toList(), <int>[7, 3, 1]);
    expect(rows.first.currency, WalletCurrency.coins);
    expect(rows.first.isCredit, isTrue);
    expect(rows[1].isCredit, isFalse);
    expect(rows[1].ref, 'fs_team:lux0');
    expect(rows[1].createdAt?.toUtc().hour, 20);
    expect(parseWalletHistory(null), isEmpty);
  });

  test('ledger reasons map to categories', () {
    expect(walletReasonKind('opening_balance'), WalletReasonKind.opening);
    expect(walletReasonKind('iap:bazaar'), WalletReasonKind.iap);
    expect(walletReasonKind('iap_refund:bazaar'), WalletReasonKind.iapRefund);
    expect(walletReasonKind('shop:coins'), WalletReasonKind.purchase);
    expect(walletReasonKind('award:daily'), WalletReasonKind.reward);
    expect(walletReasonKind('daily_gems'), WalletReasonKind.reward);
    expect(walletReasonKind('games:tournament_entry_fee'), WalletReasonKind.tournament);
    expect(walletReasonKind('games:cosmetic:striker_gold'), WalletReasonKind.cosmetic);
    expect(walletReasonKind('admin_grant:test'), WalletReasonKind.admin);
    expect(walletReasonKind('untracked:direct'), WalletReasonKind.other);
    expect(walletReasonText('iap_refund:bazaar', false), 'Purchase refunded');
  });

  test('refunded purchases have their own store message', () {
    expect(iapErrorText('refunded', false), isNot(iapErrorText('something_else', false)));
  });
}
