from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path, old, new):
    p = ROOT / path
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'Pattern not found in {path}: {old[:120]!r}')
    p.write_text(text.replace(old, new, 1))


# Main dashboard: shared POS flow for edit/return/change.
replace_once(
    'lib/presentation/dashboard/main_dashboard_layout.dart',
    '  SaleRecord? _editingSale;\n',
    "  SaleRecord? _editingSale;\n  _SaleOperationMode _saleOperationMode = _SaleOperationMode.none;\n  final Map<String, int> _operationOriginalQuantities = {};\n",
)
replace_once(
    'lib/presentation/dashboard/main_dashboard_layout.dart',
    'class MainDashboardLayout extends StatefulWidget {',
    "enum _SaleOperationMode { none, edit, returnItem, change }\n\nclass MainDashboardLayout extends StatefulWidget {",
)
replace_once(
    'lib/presentation/dashboard/main_dashboard_layout.dart',
    '    SaleDetailDialog.editHandler = _startEditingSale;\n',
    "    SaleDetailDialog.editHandler = _startEditingSale;\n    SaleDetailDialog.returnHandler = _startReturnOperation;\n    SaleDetailDialog.changeHandler = _startChangeOperation;\n",
)
replace_once(
    'lib/presentation/dashboard/main_dashboard_layout.dart',
    '    SaleDetailDialog.editHandler = null;\n',
    "    SaleDetailDialog.editHandler = null;\n    SaleDetailDialog.returnHandler = null;\n    SaleDetailDialog.changeHandler = null;\n",
)
replace_once(
    'lib/presentation/dashboard/main_dashboard_layout.dart',
    "    setState(() {\n      _editingSale = sale;\n      _cartQuantities\n",
    "    setState(() {\n      _editingSale = sale;\n      _saleOperationMode = _SaleOperationMode.edit;\n      _operationOriginalQuantities\n        ..clear()\n        ..addAll(physical);\n      _cartQuantities\n",
)

main_path = ROOT / 'lib/presentation/dashboard/main_dashboard_layout.dart'
main = main_path.read_text()
marker = '  Future<void> _updateSale() async {\n'
if marker not in main:
    raise SystemExit('Could not find _updateSale marker')

operation_methods = '''  void _startReturnOperation(SaleRecord sale) {
    _startSaleOperation(sale, _SaleOperationMode.returnItem);
  }

  void _startChangeOperation(SaleRecord sale) {
    _startSaleOperation(sale, _SaleOperationMode.change);
  }

  void _startSaleOperation(SaleRecord sale, _SaleOperationMode mode) {
    if (!sale.isCompleted || !sale.canOperateToday) {
      AppAlert.show(
        context,
        'Las devoluciones y cambios solo pueden realizarse el mismo día de la venta.',
        title: 'Operación no disponible',
        type: AppAlertType.warning,
      );
      return;
    }
    final physical = <String, int>{};
    for (final item in sale.items) {
      if (item.isElectronicBalance) continue;
      physical[item.productId] = (physical[item.productId] ?? 0) + item.quantity;
    }
    if (physical.isEmpty) {
      AppAlert.show(
        context,
        'Esta venta no contiene productos físicos disponibles para esta operación.',
        title: 'Operación no disponible',
        type: AppAlertType.warning,
      );
      return;
    }
    setState(() {
      _editingSale = sale;
      _saleOperationMode = mode;
      _operationOriginalQuantities
        ..clear()
        ..addAll(physical);
      _cartQuantities
        ..clear()
        ..addAll(physical);
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
      final removed = (_operationOriginalQuantities[id] ?? 0) - (_cartQuantities[id] ?? 0);
      if (removed > 0) result[id] = removed;
    }
    return result;
  }

  Map<String, int> _operationAddedQuantities() {
    final ids = <String>{..._operationOriginalQuantities.keys, ..._cartQuantities.keys};
    final result = <String, int>{};
    for (final id in ids) {
      final added = (_cartQuantities[id] ?? 0) - (_operationOriginalQuantities[id] ?? 0);
      if (added > 0) result[id] = added;
    }
    return result;
  }

  double _originalNetUnitPrice(SaleRecord sale, String productId) {
    for (final item in sale.items) {
      if (item.productId == productId && item.quantity > 0) {
        return item.lineTotal / item.quantity;
      }
    }
    return 0;
  }

  double get _operationDifference {
    final sale = _editingSale;
    if (sale == null || _saleOperationMode == _SaleOperationMode.edit) return 0;
    var difference = 0.0;
    for (final entry in _operationRemovedQuantities().entries) {
      difference -= _originalNetUnitPrice(sale, entry.key) * entry.value;
    }
    for (final entry in _operationAddedQuantities().entries) {
      final product = context.read<ProductProvider>().findById(entry.key);
      if (product != null) difference += product.priceForQuantity(1) * entry.value;
    }
    return difference;
  }

  String _money(double value) => '\$${value.toStringAsFixed(2)}';

  Future<void> _processReturnOperation() async {
    final sale = _editingSale;
    if (sale == null) return;
    final returned = _operationRemovedQuantities();
    if (returned.isEmpty || _operationAddedQuantities().isNotEmpty) {
      AppAlert.show(
        context,
        'En una devolución solo puedes retirar productos de la venta original. Usa Cambio para reemplazar productos.',
        title: 'Devolución inválida',
        type: AppAlertType.warning,
      );
      return;
    }
    try {
      final updated = context.read<SalesProvider>().returnItems(
        saleId: sale.id,
        quantitiesByProduct: returned,
        productProvider: context.read<ProductProvider>(),
      );
      context.read<DebtProvider>().syncInitialPayment(
        saleId: updated.id,
        clientId: updated.clientId ?? '',
        clientName: updated.clientName,
        amount: updated.effectiveCollected,
      );
      final amount = _operationDifference.abs();
      _cancelSaleOperation();
      AppAlert.show(
        context,
        'Se devolvió ${_money(amount)} al cliente y el producto regresó al inventario.',
        title: 'Devolución registrada',
        type: AppAlertType.success,
      );
    } catch (error) {
      AppAlert.show(
        context,
        error.toString().replaceFirst('Bad state: ', ''),
        title: 'No se pudo registrar la devolución',
        type: AppAlertType.error,
      );
    }
  }

  Future<void> _processChangeOperation() async {
    final sale = _editingSale;
    if (sale == null) return;
    final outgoing = _operationRemovedQuantities();
    final incoming = _operationAddedQuantities();
    final outgoingTotal = outgoing.values.fold<int>(0, (sum, value) => sum + value);
    final incomingTotal = incoming.values.fold<int>(0, (sum, value) => sum + value);
    if (outgoing.isEmpty || incoming.isEmpty || outgoingTotal != incomingTotal) {
      AppAlert.show(
        context,
        'Retira los productos que salen y agrega la misma cantidad de productos de reemplazo.',
        title: 'Cambio incompleto',
        type: AppAlertType.warning,
      );
      return;
    }
    try {
      final outgoingQueue = outgoing.entries.toList();
      final incomingQueue = incoming.entries.toList();
      final salesProvider = context.read<SalesProvider>();
      while (outgoingQueue.isNotEmpty && incomingQueue.isNotEmpty) {
        final out = outgoingQueue.removeAt(0);
        final input = incomingQueue.removeAt(0);
        final quantity = out.value < input.value ? out.value : input.value;
        salesProvider.changeItem(
          saleId: sale.id,
          sourceProductId: out.key,
          quantity: quantity,
          replacementProductId: input.key,
          productProvider: context.read<ProductProvider>(),
        );
        if (out.value > quantity) outgoingQueue.insert(0, MapEntry(out.key, out.value - quantity));
        if (input.value > quantity) incomingQueue.insert(0, MapEntry(input.key, input.value - quantity));
      }
      final updated = salesProvider.sales.firstWhere((item) => item.id == sale.id);
      context.read<DebtProvider>().syncInitialPayment(
        saleId: updated.id,
        clientId: updated.clientId ?? '',
        clientName: updated.clientName,
        amount: updated.effectiveCollected,
      );
      final difference = _operationDifference;
      _cancelSaleOperation();
      final message = difference < -0.005
          ? 'Debes devolver ${_money(difference.abs())} al cliente.'
          : difference > 0.005
              ? 'Debes cobrar ${_money(difference)} al cliente.'
              : 'El cambio no genera diferencia de dinero.';
      AppAlert.show(context, message, title: 'Cambio registrado', type: AppAlertType.success);
    } catch (error) {
      AppAlert.show(
        context,
        error.toString().replaceFirst('Bad state: ', ''),
        title: 'No se pudo registrar el cambio',
        type: AppAlertType.error,
      );
    }
  }

'''
main = main.replace(marker, operation_methods + marker, 1)
main_path.write_text(main)

replace_once(
    'lib/presentation/dashboard/main_dashboard_layout.dart',
    "      setState(() {\n        _editingSale = null;\n        _selectedPaymentMethod = AppPaymentMethods.cash;\n      });\n",
    "      setState(() {\n        _editingSale = null;\n        _saleOperationMode = _SaleOperationMode.none;\n        _operationOriginalQuantities.clear();\n        _selectedPaymentMethod = AppPaymentMethods.cash;\n      });\n",
)

main = main_path.read_text()
old = """                  onCreateSale: _editingSale == null
                      ? _createSale
                      : _updateSale,
                  isEditing: _editingSale != null,
                  ticketNumber:
"""
new = """                  onCreateSale: _editingSale == null
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
                  operationDifference: _saleOperationMode == _SaleOperationMode.none ||
                          _saleOperationMode == _SaleOperationMode.edit
                      ? null
                      : _operationDifference,
                  operationDifferenceLabel:
                      _saleOperationMode == _SaleOperationMode.returnItem
                          ? 'Devolución al cliente'
                          : _operationDifference < -0.005
                              ? 'Devolver al cliente'
                              : _operationDifference > 0.005
                                  ? 'Cobrar al cliente'
                                  : 'Diferencia',
                  onCancelOperation: _editingSale == null ? null : _cancelSaleOperation,
                  ticketNumber:
"""
if old not in main:
    raise SystemExit('SalesSummaryWithKeypad callback block not found')
main_path.write_text(main.replace(old, new, 1))

# Shared summary widgets expose the operation action and cancel button.
replace_once(
    'lib/presentation/dashboard/widgets/sales_summary_with_keypad.dart',
    '  final bool isEditing;\n',
    "  final bool isEditing;\n  final String? operationLabel;\n  final double? operationDifference;\n  final String? operationDifferenceLabel;\n  final VoidCallback? onCancelOperation;\n",
)
replace_once(
    'lib/presentation/dashboard/widgets/sales_summary_with_keypad.dart',
    '    this.isEditing = false,\n',
    "    this.isEditing = false,\n    this.operationLabel,\n    this.operationDifference,\n    this.operationDifferenceLabel,\n    this.onCancelOperation,\n",
)
replace_once(
    'lib/presentation/dashboard/widgets/sales_summary_with_keypad.dart',
    '          isEditing: widget.isEditing,\n        ),\n',
    "          isEditing: widget.isEditing,\n          operationLabel: widget.operationLabel,\n          operationDifference: widget.operationDifference,\n          operationDifferenceLabel: widget.operationDifferenceLabel,\n          onCancelOperation: widget.onCancelOperation,\n        ),\n",
)

replace_once(
    'lib/presentation/dashboard/widgets/sales_summary_panel.dart',
    '  final bool isEditing;\n',
    "  final bool isEditing;\n  final String? operationLabel;\n  final double? operationDifference;\n  final String? operationDifferenceLabel;\n  final VoidCallback? onCancelOperation;\n",
)
replace_once(
    'lib/presentation/dashboard/widgets/sales_summary_panel.dart',
    '    this.isEditing = false,\n',
    "    this.isEditing = false,\n    this.operationLabel,\n    this.operationDifference,\n    this.operationDifferenceLabel,\n    this.onCancelOperation,\n",
)
replace_once(
    'lib/presentation/dashboard/widgets/sales_summary_panel.dart',
    "        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [const Expanded(child: Text('Total', style: AppTextStyles.totalLabel)), Text('\\$${_displayTotal.toStringAsFixed(2)}', style: AppTextStyles.totalValue.copyWith(fontSize: 18))]),\n        const SizedBox(height: 8),\n        SizedBox(\n",
    """        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [const Expanded(child: Text('Total', style: AppTextStyles.totalLabel)), Text('\\$${_displayTotal.toStringAsFixed(2)}', style: AppTextStyles.totalValue.copyWith(fontSize: 18))]),
        if (operationDifference != null) ...[
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(operationDifferenceLabel ?? 'Diferencia', style: AppTextStyles.ticketLabel),
              Text(
                operationDifference!.abs() < 0.005 ? '\\$0.00' : '\\$${operationDifference!.abs().toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        if (onCancelOperation != null) ...[
          SizedBox(
            width: double.infinity,
            height: 34,
            child: OutlinedButton(onPressed: onCancelOperation, child: const Text('Cancelar')),
          ),
          const SizedBox(height: 6),
        ],
        SizedBox(
""",
)
replace_once(
    'lib/presentation/dashboard/widgets/sales_summary_panel.dart',
    "            child: Text(isEditing ? 'Actualizar venta' : AppStrings.createSaleButton, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),\n",
    "            child: Text(operationLabel ?? (isEditing ? 'Actualizar venta' : AppStrings.createSaleButton), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),\n",
)

# Detail dialog delegates return/change to the same POS screen.
replace_once(
    'lib/presentation/dashboard/widgets/sale_detail_dialog.dart',
    '  static ValueChanged<SaleRecord>? editHandler;\n',
    "  static ValueChanged<SaleRecord>? editHandler;\n  static ValueChanged<SaleRecord>? returnHandler;\n  static ValueChanged<SaleRecord>? changeHandler;\n",
)
path = ROOT / 'lib/presentation/dashboard/widgets/sale_detail_dialog.dart'
text = path.read_text()
text, count = re.subn(
    r"  Future<void> _returnItems\(BuildContext context\) async \{.*?\n  \}\n\n  Future<void> _changeItem",
    "  void _returnItems(BuildContext context) {\n    Navigator.of(context).pop();\n    returnHandler?.call(sale);\n  }\n\n  Future<void> _changeItem",
    text,
    count=1,
    flags=re.S,
)
if count != 1:
    raise SystemExit('Return dialog method not replaced')
text, count = re.subn(
    r"  Future<void> _changeItem\(BuildContext context\) async \{.*?\n  \}\n\n  String _money",
    "  void _changeItem(BuildContext context) {\n    Navigator.of(context).pop();\n    changeHandler?.call(sale);\n  }\n\n  String _money",
    text,
    count=1,
    flags=re.S,
)
if count != 1:
    raise SystemExit('Change dialog method not replaced')
path.write_text(text)

# The recorded inventory stock must never block a replacement product in a change.
replace_once(
    'lib/core/providers/sales_provider.dart',
    "    final replacement = productProvider.findById(replacementProductId); if (replacement == null) throw StateError('El producto nuevo ya no existe.'); if (replacement.stock < quantity) throw StateError('No hay suficiente existencia del producto nuevo para realizar el cambio.');\n",
    "    final replacement = productProvider.findById(replacementProductId); if (replacement == null) throw StateError('El producto nuevo ya no existe.');\n",
)
