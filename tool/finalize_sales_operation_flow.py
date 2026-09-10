from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def edit(path, transform):
    p = ROOT / path
    text = p.read_text()
    new = transform(text)
    if new == text:
        raise SystemExit(f'No changes made to {path}')
    p.write_text(new)


def add_once(text, old, new, label):
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f'Missing pattern in {label}: {old!r}')
    return text.replace(old, new, 1)


def main_dashboard(text):
    text = add_once(text, 'class MainDashboardLayout extends StatefulWidget {',
        "enum _SaleOperationMode { none, edit, returnItem, change }\n\nclass MainDashboardLayout extends StatefulWidget {", 'main')
    text = add_once(text, '  SaleRecord? _editingSale;\n',
        "  SaleRecord? _editingSale;\n  _SaleOperationMode _saleOperationMode = _SaleOperationMode.none;\n  final Map<String, int> _operationOriginalQuantities = {};\n", 'main')
    text = add_once(text, '    SaleDetailDialog.editHandler = _startEditingSale;\n',
        "    SaleDetailDialog.editHandler = _startEditingSale;\n    SaleDetailDialog.returnHandler = _startReturnOperation;\n    SaleDetailDialog.changeHandler = _startChangeOperation;\n", 'main')
    text = add_once(text, '    SaleDetailDialog.editHandler = null;\n',
        "    SaleDetailDialog.editHandler = null;\n    SaleDetailDialog.returnHandler = null;\n    SaleDetailDialog.changeHandler = null;\n", 'main')
    text = add_once(text, '      _editingSale = sale;\n      _cartQuantities\n',
        "      _editingSale = sale;\n      _saleOperationMode = _SaleOperationMode.edit;\n      _operationOriginalQuantities\n        ..clear()\n        ..addAll(physical);\n      _cartQuantities\n", 'main')

    if '_startReturnOperation' not in text:
        marker = '  Future<void> _updateSale() async {\n'
        methods = r'''  void _startReturnOperation(SaleRecord sale) =>
      _startSaleOperation(sale, _SaleOperationMode.returnItem);

  void _startChangeOperation(SaleRecord sale) =>
      _startSaleOperation(sale, _SaleOperationMode.change);

  void _startSaleOperation(SaleRecord sale, _SaleOperationMode mode) {
    if (!sale.isCompleted || !sale.canOperateToday) {
      AppAlert.show(context, 'Las devoluciones y cambios solo pueden realizarse el mismo día de la venta.', title: 'Operación no disponible', type: AppAlertType.warning);
      return;
    }
    final physical = <String, int>{};
    for (final item in sale.items) {
      if (item.isElectronicBalance) continue;
      physical[item.productId] = (physical[item.productId] ?? 0) + item.quantity;
    }
    if (physical.isEmpty) {
      AppAlert.show(context, 'Esta venta no contiene productos físicos para esta operación.', title: 'Operación no disponible', type: AppAlertType.warning);
      return;
    }
    setState(() {
      _editingSale = sale;
      _saleOperationMode = mode;
      _operationOriginalQuantities..clear()..addAll(physical);
      _cartQuantities..clear()..addAll(physical);
      _electronicBalanceSelection = [];
      _discountAmountController.clear();
      _discountPercentController.clear();
      _cashReceivedController.clear();
      _selectedPaymentMethod = AppPaymentMethods.cash;
      _selectedDebtor = null;
      _selectedNavIndex = AppNavigation.home;
    });
  }

  void _cancelSaleOperation() {
    _clearCart();
    setState(() {
      _editingSale = null;
      _saleOperationMode = _SaleOperationMode.none;
      _operationOriginalQuantities.clear();
      _selectedPaymentMethod = AppPaymentMethods.cash;
    });
  }

  Map<String, int> _operationRemovedQuantities() {
    final ids = <String>{..._operationOriginalQuantities.keys, ..._cartQuantities.keys};
    final result = <String, int>{};
    for (final id in ids) {
      final value = (_operationOriginalQuantities[id] ?? 0) - (_cartQuantities[id] ?? 0);
      if (value > 0) result[id] = value;
    }
    return result;
  }

  Map<String, int> _operationAddedQuantities() {
    final ids = <String>{..._operationOriginalQuantities.keys, ..._cartQuantities.keys};
    final result = <String, int>{};
    for (final id in ids) {
      final value = (_cartQuantities[id] ?? 0) - (_operationOriginalQuantities[id] ?? 0);
      if (value > 0) result[id] = value;
    }
    return result;
  }

  double _operationUnitPrice(SaleRecord sale, String productId) {
    for (final item in sale.items) {
      if (item.productId == productId && item.quantity > 0) return item.lineTotal / item.quantity;
    }
    return 0;
  }

  double get _operationDifference {
    final sale = _editingSale;
    if (sale == null || _saleOperationMode == _SaleOperationMode.edit) return 0;
    var value = 0.0;
    for (final entry in _operationRemovedQuantities().entries) {
      value -= _operationUnitPrice(sale, entry.key) * entry.value;
    }
    for (final entry in _operationAddedQuantities().entries) {
      final product = context.read<ProductProvider>().findById(entry.key);
      if (product != null) value += product.priceForQuantity(1) * entry.value;
    }
    return value;
  }

  String _money(double value) => '\$${value.toStringAsFixed(2)}';

  Future<void> _processReturnOperation() async {
    final sale = _editingSale;
    if (sale == null) return;
    final returned = _operationRemovedQuantities();
    if (returned.isEmpty || _operationAddedQuantities().isNotEmpty) {
      AppAlert.show(context, 'En una devolución solo puedes retirar productos de la venta original. Usa Cambio para reemplazar productos.', title: 'Devolución inválida', type: AppAlertType.warning);
      return;
    }
    try {
      final updated = context.read<SalesProvider>().returnItems(saleId: sale.id, quantitiesByProduct: returned, productProvider: context.read<ProductProvider>());
      context.read<DebtProvider>().syncInitialPayment(saleId: updated.id, clientId: updated.clientId ?? '', clientName: updated.clientName, amount: updated.effectiveCollected);
      final refund = _operationDifference.abs();
      _cancelSaleOperation();
      AppAlert.show(context, 'Devolución registrada. Monto a devolver: ${_money(refund)}.', title: 'Devolución registrada', type: AppAlertType.success);
    } catch (error) {
      AppAlert.show(context, error.toString().replaceFirst('Bad state: ', ''), title: 'No se pudo registrar la devolución', type: AppAlertType.error);
    }
  }

  Future<void> _processChangeOperation() async {
    final sale = _editingSale;
    if (sale == null) return;
    final outgoing = _operationRemovedQuantities();
    final incoming = _operationAddedQuantities();
    final outCount = outgoing.values.fold<int>(0, (a, b) => a + b);
    final inCount = incoming.values.fold<int>(0, (a, b) => a + b);
    if (outgoing.isEmpty || incoming.isEmpty || outCount != inCount) {
      AppAlert.show(context, 'Retira los productos que salen y agrega la misma cantidad de productos de reemplazo.', title: 'Cambio incompleto', type: AppAlertType.warning);
      return;
    }
    try {
      final outs = outgoing.entries.toList();
      final ins = incoming.entries.toList();
      final sales = context.read<SalesProvider>();
      while (outs.isNotEmpty && ins.isNotEmpty) {
        final out = outs.removeAt(0);
        final input = ins.removeAt(0);
        final quantity = out.value < input.value ? out.value : input.value;
        sales.changeItem(saleId: sale.id, sourceProductId: out.key, quantity: quantity, replacementProductId: input.key, productProvider: context.read<ProductProvider>());
        if (out.value > quantity) outs.insert(0, MapEntry(out.key, out.value - quantity));
        if (input.value > quantity) ins.insert(0, MapEntry(input.key, input.value - quantity));
      }
      final difference = _operationDifference;
      final updated = sales.sales.firstWhere((item) => item.id == sale.id);
      context.read<DebtProvider>().syncInitialPayment(saleId: updated.id, clientId: updated.clientId ?? '', clientName: updated.clientName, amount: updated.effectiveCollected);
      _cancelSaleOperation();
      final message = difference < -0.005 ? 'Devolver ${_money(difference.abs())} al cliente.' : difference > 0.005 ? 'Cobrar ${_money(difference)} al cliente.' : 'No hay diferencia de dinero.';
      AppAlert.show(context, message, title: 'Cambio registrado', type: AppAlertType.success);
    } catch (error) {
      AppAlert.show(context, error.toString().replaceFirst('Bad state: ', ''), title: 'No se pudo registrar el cambio', type: AppAlertType.error);
    }
  }

'''
        if marker not in text: raise SystemExit('Missing _updateSale marker')
        text = text.replace(marker, methods + marker, 1)

    old = '''                  onCreateSale: _editingSale == null
                      ? _createSale
                      : _updateSale,
                  isEditing: _editingSale != null,
                  ticketNumber:
'''
    new = '''                  onCreateSale: _editingSale == null
                      ? _createSale
                      : _saleOperationMode == _SaleOperationMode.edit
                          ? _updateSale
                          : _saleOperationMode == _SaleOperationMode.returnItem
                              ? _processReturnOperation
                              : _processChangeOperation,
                  isEditing: _editingSale != null,
                  operationLabel: _saleOperationMode == _SaleOperationMode.edit
                      ? 'Actualizar venta'
                      : _saleOperationMode == _SaleOperationMode.returnItem
                          ? 'Registrar devolución'
                          : _saleOperationMode == _SaleOperationMode.change
                              ? 'Registrar cambio'
                              : null,
                  operationDifference: _saleOperationMode == _SaleOperationMode.none || _saleOperationMode == _SaleOperationMode.edit ? null : _operationDifference,
                  operationDifferenceLabel: _saleOperationMode == _SaleOperationMode.returnItem
                      ? 'Devolución al cliente'
                      : _operationDifference < -0.005
                          ? 'Devolver al cliente'
                          : _operationDifference > 0.005
                              ? 'Cobrar al cliente'
                              : 'Diferencia',
                  onCancelOperation: _editingSale == null ? null : _cancelSaleOperation,
                  ticketNumber:
'''
    if old not in text: raise SystemExit('Missing summary callback block')
    text = text.replace(old, new, 1)
    text = text.replace('''      setState(() {
        _editingSale = null;
        _selectedPaymentMethod = AppPaymentMethods.cash;
      });''', '''      setState(() {
        _editingSale = null;
        _saleOperationMode = _SaleOperationMode.none;
        _operationOriginalQuantities.clear();
        _selectedPaymentMethod = AppPaymentMethods.cash;
      });''', 1)
    return text


def summary_with_keypad(text):
    text = add_once(text, '  final bool isEditing;\n', "  final bool isEditing;\n  final String? operationLabel;\n  final double? operationDifference;\n  final String? operationDifferenceLabel;\n  final VoidCallback? onCancelOperation;\n", 'keypad')
    text = add_once(text, '    this.isEditing = false,\n', "    this.isEditing = false,\n    this.operationLabel,\n    this.operationDifference,\n    this.operationDifferenceLabel,\n    this.onCancelOperation,\n", 'keypad')
    text = add_once(text, '          isEditing: widget.isEditing,\n', "          isEditing: widget.isEditing,\n          operationLabel: widget.operationLabel,\n          operationDifference: widget.operationDifference,\n          operationDifferenceLabel: widget.operationDifferenceLabel,\n          onCancelOperation: widget.onCancelOperation,\n", 'keypad')
    return text


def summary_panel(text):
    text = add_once(text, '  final bool isEditing;\n', "  final bool isEditing;\n  final String? operationLabel;\n  final double? operationDifference;\n  final String? operationDifferenceLabel;\n  final VoidCallback? onCancelOperation;\n", 'panel')
    text = add_once(text, '    this.isEditing = false,\n', "    this.isEditing = false,\n    this.operationLabel,\n    this.operationDifference,\n    this.operationDifferenceLabel,\n    this.onCancelOperation,\n", 'panel')
    text = add_once(text, "        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [const Expanded(child: Text('Total', style: AppTextStyles.totalLabel)), Text('\\$${_displayTotal.toStringAsFixed(2)}', style: AppTextStyles.totalValue.copyWith(fontSize: 18))]),\n        const SizedBox(height: 8),\n        SizedBox(\n", """        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [const Expanded(child: Text('Total', style: AppTextStyles.totalLabel)), Text('\\$${_displayTotal.toStringAsFixed(2)}', style: AppTextStyles.totalValue.copyWith(fontSize: 18))]),
        if (operationDifference != null) ...[
          const SizedBox(height: 7),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(operationDifferenceLabel ?? 'Diferencia', style: AppTextStyles.ticketLabel),
            Text(operationDifference!.abs() < 0.005 ? '\\$0.00' : '\\$${operationDifference!.abs().toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
          ]),
        ],
        const SizedBox(height: 8),
        if (onCancelOperation != null) ...[
          SizedBox(width: double.infinity, height: 34, child: OutlinedButton(onPressed: onCancelOperation, child: const Text('Cancelar'))),
          const SizedBox(height: 6),
        ],
        SizedBox(
""", 'panel')
    text = text.replace("child: Text(isEditing ? 'Actualizar venta' : AppStrings.createSaleButton,", "child: Text(operationLabel ?? (isEditing ? 'Actualizar venta' : AppStrings.createSaleButton),", 1)
    return text


def sale_detail(text):
    text = add_once(text, '  static ValueChanged<SaleRecord>? editHandler;\n', "  static ValueChanged<SaleRecord>? editHandler;\n  static ValueChanged<SaleRecord>? returnHandler;\n  static ValueChanged<SaleRecord>? changeHandler;\n", 'detail')
    text = re.sub(r'(?m)^\s*onPressed:\s*\(\)\s*=>\s*_returnItems\(context\),\s*$', '            onPressed: () {\n              Navigator.of(context).pop();\n              returnHandler?.call(sale);\n            },', text, count=1)
    text = re.sub(r'(?m)^\s*onPressed:\s*\(\)\s*=>\s*_changeItem\(context\),\s*$', '            onPressed: () {\n              Navigator.of(context).pop();\n              changeHandler?.call(sale);\n            },', text, count=1)
    return text


def provider(text):
    text2, count = re.subn(r"\s*if \(replacement\.stock < quantity\) throw StateError\('No hay suficiente existencia del producto nuevo para realizar el cambio\.\');", '', text, count=1)
    if count == 0 and 'replacement.stock < quantity' in text:
        raise SystemExit('Replacement stock guard found but could not remove it')
    return text2

edit('lib/presentation/dashboard/main_dashboard_layout.dart', main_dashboard)
edit('lib/presentation/dashboard/widgets/sales_summary_with_keypad.dart', summary_with_keypad)
edit('lib/presentation/dashboard/widgets/sales_summary_panel.dart', summary_panel)
edit('lib/presentation/dashboard/widgets/sale_detail_dialog.dart', sale_detail)
edit('lib/core/providers/sales_provider.dart', provider)
print('Sales operation POS flow finalized.')
