import 'package:flutter/foundation.dart';
import 'package:stellar_pos/core/models/electronic_balance.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/electronic_balance_provider.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';

class SalesProvider extends ChangeNotifier {
  final List<SaleRecord> _sales = [];
  int _nextTicketNumber = 1;
  List<SaleRecord> get sales => List.unmodifiable(_sales);
  SaleRecord? get latestSale => _sales.isEmpty ? null : _sales.last;
  String get nextTicketNumberPreview => _nextTicketNumber.toString().padLeft(8, '0');

  SaleRecord createSale({required Map<String, int> cartQuantities, required ProductProvider productProvider, required String paymentMethodLabel, required String? clientId, required String clientName, required double subtotal, required double discountPercent, required double discountAmount, required double cardFeeAmount, required double total, required double received, required double change, List<ElectronicBalanceCartSale> electronicSales = const [], ElectronicBalanceProvider? electronicBalanceProvider}) {
    if (cartQuantities.isEmpty && electronicSales.isEmpty) throw StateError('No hay productos seleccionados.');
    if (electronicSales.isNotEmpty && electronicBalanceProvider == null) throw StateError('No se pudo acceder al saldo electrónico.');
    final now = DateTime.now(); final ticketNumber = nextTicketNumberPreview; final saleId = '${now.microsecondsSinceEpoch}-$ticketNumber'; final items = <SaleItemRecord>[];
    for (final entry in cartQuantities.entries) {
      final product = productProvider.findById(entry.key); if (product == null) throw StateError('Uno de los productos de la venta ya no existe.');
      final quantity = entry.value; if (quantity <= 0) throw StateError('La cantidad de un producto debe ser mayor que cero.');
      final lineSubtotal = product.priceForQuantity(quantity); final lineDiscount = subtotal <= 0 ? 0.0 : discountAmount * (lineSubtotal / subtotal);
      final effectiveUnitPrice = quantity <= 0 ? product.price : lineSubtotal / quantity;
      items.add(SaleItemRecord(productId: product.id, productName: product.name, unit: product.unit, brand: product.brand, barcode: product.barcode, cost: product.cost, unitPrice: effectiveUnitPrice, quantity: quantity, lineSubtotal: lineSubtotal, discount: lineDiscount, lineTotal: lineSubtotal - lineDiscount, imageData: product.imageData));
    }
    final balanceProvider = electronicBalanceProvider; final balanceAccounts = <String, ElectronicBalanceAccount>{};
    if (balanceProvider != null) for (final electronicSale in electronicSales) {
      final account = balanceProvider.findAccount(electronicSale.accountId); if (account == null) throw StateError('La compañía de una recarga ya no existe.');
      if (electronicSale.quantity <= 0 || electronicSale.amount <= 0) throw StateError('La cantidad de una recarga debe ser mayor que cero.');
      if (!{'Saldo', 'Internet', 'Llamada'}.contains(electronicSale.category)) throw StateError('El tipo de recarga no es válido.');
      if (account.amountsForCategory(electronicSale.category).every((amount) => (amount - electronicSale.amount).abs() > 0.000001)) throw StateError('El monto de una recarga ya no está configurado para ${account.companyName}.');
      balanceAccounts[electronicSale.accountId] = account;
    }
    for (final electronicSale in electronicSales) {
      final account = balanceAccounts[electronicSale.accountId]!; final lineSubtotal = electronicSale.amount * electronicSale.quantity; final lineDiscount = subtotal <= 0 ? 0.0 : discountAmount * (lineSubtotal / subtotal); final providerCost = electronicSale.amount * (1 - account.commissionRate / 100);
      items.add(SaleItemRecord(productId: 'electronic:${electronicSale.accountId}:${electronicSale.category}:${electronicSale.amount.toStringAsFixed(4)}', productName: '${account.companyName} · ${electronicSale.category}', unit: electronicSale.category, barcode: '', cost: providerCost, unitPrice: electronicSale.amount, quantity: electronicSale.quantity, lineSubtotal: lineSubtotal, discount: lineDiscount, lineTotal: lineSubtotal - lineDiscount, isElectronicBalance: true, electronicBalanceAccountId: electronicSale.accountId, electronicBalanceCategory: electronicSale.category));
    }
    if (items.isEmpty) throw StateError('No hay líneas válidas para registrar la venta.');
    if (electronicSales.isNotEmpty) {
      final accountIds = electronicSales.map((sale) => sale.accountId).toSet();
      for (final accountId in accountIds) {
        final registered = balanceProvider!.registerSales(accountId: accountId, saleId: saleId, sales: electronicSales.where((sale) => sale.accountId == accountId).map((sale) => ElectronicBalanceSale(amount: sale.amount, quantity: sale.quantity, category: sale.category, description: '${sale.companyName} · ${sale.category}')).toList());
        if (!registered) throw StateError('No se pudo registrar una de las ventas de saldo.');
      }
    }
    final sale = SaleRecord(id: saleId, ticketNumber: ticketNumber, createdAt: now, clientId: clientId, clientName: clientName, paymentMethod: paymentMethodLabel, items: List.unmodifiable(items), subtotal: subtotal, discountPercent: discountPercent, discountAmount: discountAmount, cardFeeAmount: cardFeeAmount, total: total, received: received, change: change);
    _sales.add(sale); _nextTicketNumber++;
    for (final item in items.where((item) => !item.isElectronicBalance)) { final product = productProvider.findById(item.productId); if (product != null) productProvider.updateProduct(product.copyWith(stock: product.stock - item.quantity)); }
    notifyListeners(); return sale;
  }

  SaleRecord updateSale({required String saleId, required List<SaleItemRecord> updatedItems, required ProductProvider productProvider, ElectronicBalanceProvider? electronicBalanceProvider}) {
    final index = _sales.indexWhere((sale) => sale.id == saleId); if (index < 0) throw StateError('La venta que intentas editar ya no existe.'); if (updatedItems.isEmpty) throw StateError('La venta debe conservar al menos un producto.');
    final oldSale = _sales[index]; final oldPhysical = <String, int>{}; for (final item in oldSale.items) if (!item.isElectronicBalance) oldPhysical[item.productId] = (oldPhysical[item.productId] ?? 0) + item.quantity;
    final newPhysical = <String, int>{}; for (final item in updatedItems) { if (item.isElectronicBalance) continue; if (item.quantity <= 0) throw StateError('La cantidad de un producto debe ser mayor que cero.'); if (productProvider.findById(item.productId) == null) throw StateError('Uno de los productos seleccionados ya no existe.'); newPhysical[item.productId] = (newPhysical[item.productId] ?? 0) + item.quantity; }
    final hasElectronic = updatedItems.any((item) => item.isElectronicBalance); if (hasElectronic && electronicBalanceProvider == null) throw StateError('No se pudo acceder al saldo electrónico.');
    if (hasElectronic) for (final item in updatedItems.where((item) => item.isElectronicBalance)) { final accountId = item.electronicBalanceAccountId; final category = item.electronicBalanceCategory; final account = accountId == null ? null : electronicBalanceProvider!.findAccount(accountId); if (account == null || category == null) throw StateError('Una recarga de la venta ya no está disponible.'); if (account.amountsForCategory(category).every((amount) => (amount - item.unitPrice).abs() > 0.000001)) throw StateError('Uno de los montos de recarga ya no está configurado.'); }
    if (oldSale.items.any((item) => item.isElectronicBalance)) if (electronicBalanceProvider == null || !electronicBalanceProvider.reverseSale(oldSale.id)) throw StateError('No se pudo revertir el saldo electrónico de la venta.');
    for (final entry in oldPhysical.entries) { final product = productProvider.findById(entry.key); if (product != null) productProvider.updateProduct(product.copyWith(stock: product.stock + entry.value)); }
    final subtotal = updatedItems.fold<double>(0, (sum, item) { if (item.isElectronicBalance) return sum + item.unitPrice * item.quantity; final product = productProvider.findById(item.productId); return sum + (product?.priceForQuantity(item.quantity) ?? item.unitPrice * item.quantity); });
    final oldDiscountRate = oldSale.subtotal <= 0 ? 0 : oldSale.discountAmount / oldSale.subtotal; final discountAmount = subtotal * oldDiscountRate; final cardBase = subtotal - discountAmount; final cardFeeRate = cardBase <= 0 ? 0 : oldSale.cardFeeAmount / cardBase; final cardFeeAmount = cardBase * cardFeeRate; final total = subtotal - discountAmount + cardFeeAmount; final discountPercent = (oldSale.subtotal <= 0 ? oldSale.discountPercent : oldDiscountRate * 100).toDouble();
    final finalItems = <SaleItemRecord>[];
    for (final item in updatedItems) {
      final isElectronic = item.isElectronicBalance; final product = isElectronic ? null : productProvider.findById(item.productId); final account = isElectronic && item.electronicBalanceAccountId != null ? electronicBalanceProvider!.findAccount(item.electronicBalanceAccountId!) : null;
      final lineSubtotal = isElectronic ? item.unitPrice * item.quantity : (product?.priceForQuantity(item.quantity) ?? item.unitPrice * item.quantity); final lineDiscount = subtotal <= 0 ? 0.0 : discountAmount * lineSubtotal / subtotal; final cost = product?.cost ?? (account == null ? item.cost : item.unitPrice * (1 - account.commissionRate / 100)); final name = isElectronic && account != null ? '${account.companyName} · ${item.electronicBalanceCategory ?? item.unit}' : (product?.name ?? item.productName); final effectiveUnitPrice = isElectronic ? item.unitPrice : (item.quantity <= 0 ? item.unitPrice : lineSubtotal / item.quantity);
      finalItems.add(SaleItemRecord(productId: item.productId, productName: name, unit: product?.unit ?? item.unit, brand: product?.brand ?? item.brand, barcode: product?.barcode ?? '', cost: cost, unitPrice: effectiveUnitPrice, quantity: item.quantity, lineSubtotal: lineSubtotal, discount: lineDiscount, lineTotal: lineSubtotal - lineDiscount, imageData: product?.imageData ?? item.imageData, isElectronicBalance: isElectronic, electronicBalanceAccountId: item.electronicBalanceAccountId, electronicBalanceCategory: item.electronicBalanceCategory));
    }
    if (hasElectronic) {
      final provider = electronicBalanceProvider!; final groups = <String, List<SaleItemRecord>>{}; for (final item in finalItems.where((item) => item.isElectronicBalance)) { final accountId = item.electronicBalanceAccountId; if (accountId != null) groups.putIfAbsent(accountId, () => []).add(item); }
      for (final entry in groups.entries) { final registered = provider.registerSales(accountId: entry.key, saleId: oldSale.id, sales: entry.value.map((item) => ElectronicBalanceSale(amount: item.unitPrice, quantity: item.quantity, category: item.electronicBalanceCategory ?? item.unit, description: item.productName)).toList()); if (!registered) throw StateError('No se pudo registrar una de las recargas modificadas.'); }
    }
    for (final entry in newPhysical.entries) { final product = productProvider.findById(entry.key); if (product != null) productProvider.updateProduct(product.copyWith(stock: product.stock - entry.value)); }
    final updated = SaleRecord(id: oldSale.id, ticketNumber: oldSale.ticketNumber, createdAt: oldSale.createdAt, clientId: oldSale.clientId, clientName: oldSale.clientName, paymentMethod: oldSale.paymentMethod, items: List.unmodifiable(finalItems), subtotal: subtotal, discountPercent: discountPercent, discountAmount: discountAmount, cardFeeAmount: cardFeeAmount, total: total, received: 0, change: 0);
    _sales[index] = updated; notifyListeners(); return updated;
  }

  bool deleteSale({required String saleId, required ProductProvider productProvider, ElectronicBalanceProvider? electronicBalanceProvider}) {
    final index = _sales.indexWhere((sale) => sale.id == saleId); if (index < 0) return false; final sale = _sales[index];
    if (sale.items.any((item) => item.isElectronicBalance)) if (electronicBalanceProvider == null || !electronicBalanceProvider.reverseSale(sale.id)) return false;
    for (final item in sale.items.where((item) => !item.isElectronicBalance)) { final product = productProvider.findById(item.productId); if (product != null) productProvider.updateProduct(product.copyWith(stock: product.stock + item.quantity)); }
    _sales.removeAt(index); notifyListeners(); return true;
  }

  SaleRecord? findByTicketNumber(String ticketNumber) { final normalized = ticketNumber.trim().replaceFirst('#', ''); if (normalized.isEmpty) return null; for (final sale in _sales) if (sale.ticketNumber == normalized) return sale; return null; }
  void clearSales() { if (_sales.isEmpty) return; _sales.clear(); _nextTicketNumber = 1; notifyListeners(); }
}

class ElectronicBalanceCartSale {
  final String accountId; final String companyName; final String category; final double amount; final int quantity;
  const ElectronicBalanceCartSale({required this.accountId, required this.companyName, required this.category, required this.amount, required this.quantity});
}
