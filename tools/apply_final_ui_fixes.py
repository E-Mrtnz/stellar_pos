from pathlib import Path
import subprocess

ROOT = Path('.')


def read(path):
    return (ROOT / path).read_text()


def write(path, text):
    (ROOT / path).write_text(text)


# Restore the dedicated electronic-balance management screen from the last
# version where it was separate from the sales-history screen.
electronic = 'lib/presentation/electronic_balance/electronic_balance_layout.dart'
old = subprocess.check_output(
    ['git', 'show', 'fc26c30a9148a8a7f5820f2b49aa599a80a3c16e:' + electronic],
    text=True,
)
s = old
s = s.replace(
    '                        onSale: () => _sale(context, account),\n                        onEdit:',
    '                        onSale: () => _sale(context, account),\n                        onHistory: () => _history(context, account),\n                        onEdit:',
    1,
)
s = s.replace(
    '  Future<void> _delete(BuildContext context, ElectronicBalanceAccount account) async {',
    "  Future<void> _history(BuildContext context, ElectronicBalanceAccount account) => showDialog<void>(\n        context: context,\n        builder: (_) => _BalanceSalesHistoryDialog(account: account),\n      );\n\n  Future<void> _delete(BuildContext context, ElectronicBalanceAccount account) async {",
    1,
)
s = s.replace(
    '  final VoidCallback onSale;\n  final VoidCallback onEdit;',
    '  final VoidCallback onSale;\n  final VoidCallback onHistory;\n  final VoidCallback onEdit;',
    1,
)
s = s.replace(
    'const _BalanceAccountCard({required this.account, required this.sold, required this.profit, required this.onPurchase, required this.onSale, required this.onEdit, required this.onDelete});',
    'const _BalanceAccountCard({required this.account, required this.sold, required this.profit, required this.onPurchase, required this.onSale, required this.onHistory, required this.onEdit, required this.onDelete});',
    1,
)
s = s.replace(
    '              IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),',
    "              IconButton(tooltip: 'Historial de ventas', onPressed: onHistory, icon: const Icon(Icons.receipt_long_outlined)),\n              IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),",
    1,
)
history = r'''

class _BalanceSalesHistoryDialog extends StatelessWidget {
  final ElectronicBalanceAccount account;
  const _BalanceSalesHistoryDialog({required this.account});

  @override
  Widget build(BuildContext context) {
    final transactions = context
        .watch<ElectronicBalanceProvider>()
        .transactionsFor(account.id)
        .where((t) => t.type == ElectronicBalanceTransactionType.sale)
        .toList();
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Historial de ventas de saldo', style: AppTextStyles.sectionTitle),
                Text(account.companyName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ])),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 12),
            if (transactions.isEmpty)
              const Expanded(child: Center(child: Text('No hay ventas de saldo registradas.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))))
            else
              Expanded(child: Container(
                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: const BoxDecoration(color: AppColors.inputBackground, border: Border(bottom: BorderSide(color: AppColors.border))),
                    child: const Row(children: [
                      SizedBox(width: 92, child: Text('Fecha', style: AppTextStyles.ticketLabel)),
                      SizedBox(width: 88, child: Text('Categoría', style: AppTextStyles.ticketLabel)),
                      Expanded(child: Text('Detalle', style: AppTextStyles.ticketLabel)),
                      SizedBox(width: 85, child: Text('Monto', textAlign: TextAlign.right, style: AppTextStyles.ticketLabel)),
                      SizedBox(width: 85, child: Text('Ganancia', textAlign: TextAlign.right, style: AppTextStyles.ticketLabel)),
                    ]),
                  ),
                  Expanded(child: ListView.separated(
                    itemCount: transactions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (_, index) {
                      final t = transactions[index];
                      final date = '${t.createdAt.day.toString().padLeft(2, '0')}/${t.createdAt.month.toString().padLeft(2, '0')} ${t.createdAt.hour.toString().padLeft(2, '0')}:${t.createdAt.minute.toString().padLeft(2, '0')}';
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(children: [
                          SizedBox(width: 92, child: Text(date, style: const TextStyle(fontSize: 10))),
                          SizedBox(width: 88, child: Text(t.category, style: const TextStyle(fontSize: 10))),
                          Expanded(child: Text(t.description.isEmpty ? 'Venta de saldo' : t.description, style: const TextStyle(fontSize: 10))),
                          SizedBox(width: 85, child: Text('\$${t.amount.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
                          SizedBox(width: 85, child: Text('\$${t.profit.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.successGreen))),
                        ]),
                      );
                    },
                  )),
                ]),
              )),
          ]),
        ),
      ),
    );
  }
}
'''
s = s.rstrip() + history
write(electronic, s)

# Sales: separate filter for Todas / Productos / Saldo and normal-looking popup buttons.
path = 'lib/presentation/sales/sales_layout.dart'
s = read(path)
s = s.replace(
    'enum _SalesPaymentFilter { all, cash, card, transfer, credit }',
    'enum _SalesPaymentFilter { all, cash, card, transfer, credit }\nenum _SalesTypeFilter { all, products, electronic }',
    1,
)
s = s.replace(
    '  _SalesPaymentFilter _paymentFilter = _SalesPaymentFilter.all;\n',
    '  _SalesPaymentFilter _paymentFilter = _SalesPaymentFilter.all;\n  _SalesTypeFilter _typeFilter = _SalesTypeFilter.all;\n',
    1,
)
s = s.replace(
    '      if (!_paymentMatches(sale)) return false;\n',
    '      if (!_paymentMatches(sale)) return false;\n      if (!_typeMatches(sale)) return false;\n',
    1,
)
marker = '  Map<String, double> _paidBySale('
type_method = '''  bool _typeMatches(SaleRecord sale) {\n    final hasElectronic = sale.items.any((item) => item.isElectronicBalance);\n    final hasProducts = sale.items.any((item) => !item.isElectronicBalance);\n    switch (_typeFilter) {\n      case _SalesTypeFilter.all: return true;\n      case _SalesTypeFilter.products: return hasProducts;\n      case _SalesTypeFilter.electronic: return hasElectronic;\n    }\n  }\n\n'''
if marker not in s:
    raise SystemExit('sales type marker not found')
s = s.replace(marker, type_method + marker, 1)
s = s.replace(
    '        child: OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.tune_outlined, size: 17), label: Text(_periodLabel())),',
    '        child: _menuSurface(Icons.tune_outlined, _periodLabel()),',
    1,
)
s = s.replace(
    '        child: OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.filter_alt_outlined, size: 17), label: Text(_paymentLabel())),',
    '        child: _menuSurface(Icons.filter_alt_outlined, _paymentLabel()),',
    1,
)
payment_block = '''      PopupMenuButton<_SalesPaymentFilter>(\n        onSelected: (value) => setState(() => _paymentFilter = value),\n        itemBuilder: (_) => const [\n          PopupMenuItem(value: _SalesPaymentFilter.all, child: Text('Todos')),\n          PopupMenuItem(value: _SalesPaymentFilter.cash, child: Text('Efectivo')),\n          PopupMenuItem(value: _SalesPaymentFilter.card, child: Text('Tarjeta')),\n          PopupMenuItem(value: _SalesPaymentFilter.transfer, child: Text('Transferencia')),\n          PopupMenuItem(value: _SalesPaymentFilter.credit, child: Text('Fiado')),\n        ],\n        child: _menuSurface(Icons.filter_alt_outlined, _paymentLabel()),\n      ),'''
type_block = '''      PopupMenuButton<_SalesTypeFilter>(\n        onSelected: (value) => setState(() => _typeFilter = value),\n        itemBuilder: (_) => const [\n          PopupMenuItem(value: _SalesTypeFilter.all, child: Text('Todas')),\n          PopupMenuItem(value: _SalesTypeFilter.products, child: Text('Productos')),\n          PopupMenuItem(value: _SalesTypeFilter.electronic, child: Text('Saldo electrónico')),\n        ],\n        child: _menuSurface(Icons.category_outlined, _typeLabel()),\n      ),\n'''
if payment_block not in s:
    raise SystemExit('sales payment block not found')
s = s.replace(payment_block, type_block + payment_block, 1)
label_marker = '  String _paymentLabel() {'
helpers = '''  String _typeLabel() {\n    switch (_typeFilter) {\n      case _SalesTypeFilter.all: return 'Todas';\n      case _SalesTypeFilter.products: return 'Productos';\n      case _SalesTypeFilter.electronic: return 'Saldo';\n    }\n  }\n\n  Widget _menuSurface(IconData icon, String label) {\n    return Container(\n      constraints: const BoxConstraints(minHeight: 42),\n      padding: const EdgeInsets.symmetric(horizontal: 12),\n      decoration: BoxDecoration(\n        color: AppColors.cardBackground,\n        borderRadius: BorderRadius.circular(10),\n        border: Border.all(color: AppColors.border),\n        boxShadow: const [BoxShadow(color: AppColors.shadowColor, blurRadius: 7, offset: Offset(0, 2))],\n      ),\n      child: Row(mainAxisSize: MainAxisSize.min, children: [\n        Icon(icon, size: 17, color: AppColors.textSecondary),\n        const SizedBox(width: 7),\n        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),\n      ]),\n    );\n  }\n\n'''
if label_marker not in s:
    raise SystemExit('sales label marker not found')
s = s.replace(label_marker, helpers + label_marker, 1)
s = s.replace(
    '      padding: const EdgeInsets.fromLTRB(14, 9, 14, 8),',
    '      padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),',
    1,
)
s = s.replace(
    '        color: AppColors.inputBackground,\n        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.cardRadius)),',
    '        color: AppColors.inputBackground,\n        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.cardRadius)),\n        boxShadow: const [BoxShadow(color: AppColors.shadowColor, blurRadius: 4, offset: Offset(0, 1))],',
    1,
)
write(path, s)

# Purchases: shadow the filter surfaces and add a visible list header.
path = 'lib/presentation/purchases/purchases_layout_legacy.dart'
s = read(path)
s = s.replace(
    '        color: AppColors.cardBackground,\n        borderRadius: BorderRadius.circular(AppDimensions.searchFieldRadius),\n        border: Border.all(color: AppColors.border),',
    '        color: AppColors.cardBackground,\n        borderRadius: BorderRadius.circular(AppDimensions.searchFieldRadius),\n        border: Border.all(color: AppColors.border),\n        boxShadow: const [BoxShadow(color: AppColors.shadowColor, blurRadius: 7, offset: Offset(0, 2))],',
    1,
)
marker = '''          const SizedBox(height: 10),\n          Expanded(\n            child: purchases.isEmpty\n                ? const _EmptyState()'''
replacement = '''          const SizedBox(height: 10),\n          if (purchases.isNotEmpty) ...[\n            Container(\n              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),\n              decoration: const BoxDecoration(\n                color: AppColors.inputBackground,\n                border: Border(bottom: BorderSide(color: AppColors.border)),\n                borderRadius: BorderRadius.vertical(top: Radius.circular(9)),\n              ),\n              child: const Row(children: [\n                SizedBox(width: 42),\n                SizedBox(width: 10),\n                Expanded(child: Text('Proveedor / factura', style: AppTextStyles.ticketLabel)),\n                SizedBox(width: 100, child: Text('Total', textAlign: TextAlign.right, style: AppTextStyles.ticketLabel)),\n                SizedBox(width: 76, child: Text('Pago', textAlign: TextAlign.right, style: AppTextStyles.ticketLabel)),\n                SizedBox(width: 86, child: Text('Artículos', textAlign: TextAlign.right, style: AppTextStyles.ticketLabel)),\n                SizedBox(width: 18),\n              ]),\n            ),\n            const SizedBox(height: 4),\n          ],\n          Expanded(\n            child: purchases.isEmpty\n                ? const _EmptyState()'''
if marker not in s:
    raise SystemExit('purchase header marker not found')
s = s.replace(marker, replacement, 1)
write(path, s)

# Inventory: the export action is a PopupMenuButton, so its child must not be a
# disabled OutlinedButton; render it as a normal elevated surface instead.
path = 'lib/presentation/Inventory/inventory_layout_legacy.dart'
s = read(path)
s = s.replace(
    '      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),\n    );',
    '      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),\n      elevation: 1,\n      shadowColor: AppColors.shadowColor,\n    );',
    1,
)
old_export = '''            child: OutlinedButton.icon(\n              onPressed: null,\n              style: buttonStyle,\n              icon: _isExporting\n                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))\n                  : const Icon(Icons.download_outlined, size: 18),\n              label: const Text('Descargar inventario'),\n            ),'''
new_export = '''            child: Container(\n              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),\n              decoration: BoxDecoration(\n                color: AppColors.cardBackground,\n                borderRadius: BorderRadius.circular(8),\n                border: Border.all(color: AppColors.border),\n                boxShadow: const [BoxShadow(color: AppColors.shadowColor, blurRadius: 6, offset: Offset(0, 2))],\n              ),\n              child: Row(mainAxisSize: MainAxisSize.min, children: [\n                _isExporting\n                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))\n                    : const Icon(Icons.download_outlined, size: 18, color: AppColors.textPrimary),\n                const SizedBox(width: 8),\n                const Text('Descargar inventario', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),\n              ]),\n            ),'''
if old_export not in s:
    raise SystemExit('inventory export marker not found')
s = s.replace(old_export, new_export, 1)
write(path, s)

# The create-client dropdown is already wired through SalesSummaryWithKeypad;
# keep the explicit action visible even when there are zero clients.

print('Final UI fixes applied.')
