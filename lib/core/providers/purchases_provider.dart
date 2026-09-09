import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/domain/services/purchase_totals_service.dart';
import 'package:stellar_pos/core/models/purchase.dart';

class PurchasesProvider extends ChangeNotifier {
  PurchasesProvider({PurchaseTotalsService? service})
      : _service = service ?? const PurchaseTotalsService();

  final PurchaseTotalsService _service;
  final List<PurchaseRecord> _purchases = [];

  List<PurchaseRecord> get purchases => List.unmodifiable(_purchases);

  double totalFor(Iterable<PurchaseRecord> records) =>
      _service.totalForPurchases(records);

  void addPurchase(PurchaseRecord purchase) {
    _purchases.add(purchase);
    notifyListeners();
  }

  void removePurchase(String id) {
    final before = _purchases.length;
    _purchases.removeWhere((purchase) => purchase.id == id);
    if (_purchases.length != before) notifyListeners();
  }

  void clearPurchases() {
    if (_purchases.isEmpty) return;
    _purchases.clear();
    notifyListeners();
  }
}
