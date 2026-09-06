import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/models/purchase.dart';

class PurchasesProvider extends ChangeNotifier {
  final List<PurchaseRecord> _purchases = [];

  List<PurchaseRecord> get purchases => List.unmodifiable(_purchases);

  double totalFor(Iterable<PurchaseRecord> records) =>
      records.fold(0.0, (sum, purchase) => sum + purchase.total);

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
