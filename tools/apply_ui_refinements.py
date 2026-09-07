from pathlib import Path
import shutil

ROOT = Path('.')

# Shared full-face toggle.
(ROOT / 'lib/presentation/widgets/settings_toggle_tile.dart').write_text('''import \'package:flutter/material.dart\';
import \'package:stellar_pos/core/constants/app_constants.dart\';

class SettingsToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;

  const SettingsToggleTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.icon = Icons.settings_suggest_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.inputBackground,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: value ? AppColors.primary.withAlpha(80) : AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: value ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged, activeColor: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
''', encoding='utf-8')

# Inventory wrapper: the legacy layout now receives settings directly.
(ROOT / 'lib/presentation/Inventory/inventory_layout.dart').write_text('''import \'package:flutter/material.dart\';
import \'package:provider/provider.dart\';
import \'package:stellar_pos/core/providers/general_settings_provider.dart\';
import \'inventory_layout_legacy.dart\' as legacy;

class InventoryLayout extends StatelessWidget {
  const InventoryLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GeneralSettingsProvider(),
      child: const legacy.InventoryLayout(),
    );
  }
}
''', encoding='utf-8')

# Inventory buttons: remove them from the widget tree when disabled.
p = ROOT / 'lib/presentation/Inventory/inventory_layout_legacy.dart'
s = p.read_text(encoding='utf-8')
if 'general_settings_provider.dart' not in s:
    s = s.replace("import 'package:stellar_pos/core/providers/catalog_provider.dart';\n", "import 'package:stellar_pos/core/providers/catalog_provider.dart';\nimport 'package:stellar_pos/core/providers/general_settings_provider.dart';\n", 1)
start = s.index('  Widget _buildFileActions() {')
end = s.index('\n  Widget _buildInventoryTable(', start)
s = s[:start] + '''  Widget _buildFileActions() {
    final settings = context.watch<GeneralSettingsProvider>();
    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: AppColors.textPrimary,
      side: const BorderSide(color: AppColors.border),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (settings.showInventoryImport)
          OutlinedButton.icon(
            onPressed: _isImporting || _isExporting ? null : _importInventory,
            style: buttonStyle,
            icon: _isImporting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text('Subir inventario'),
          ),
        if (settings.showInventoryImport && settings.showInventoryExport)
          const SizedBox(width: 8),
        if (settings.showInventoryExport)
          PopupMenuButton<String>(
            enabled: !_isImporting && !_isExporting,
            onSelected: (value) => value == 'excel' ? _exportExcel() : _exportPdf(),
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'excel',
                child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.table_chart_outlined), title: Text('Descargar Excel')),
              ),
              PopupMenuItem<String>(
                value: 'pdf',
                child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.picture_as_pdf_outlined), title: Text('Descargar PDF')),
              ),
            ],
            child: OutlinedButton.icon(
              onPressed: null,
              style: buttonStyle,
              icon: _isExporting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_outlined, size: 18),
              label: const Text('Descargar inventario'),
            ),
          ),
      ],
    );
  }
''' + s[end:]
p.write_text(s, encoding='utf-8')

# General settings: same full-face toggle.
p = ROOT / 'lib/presentation/settings/printer_settings_layout.dart'
s = p.read_text(encoding='utf-8')
if 'settings_toggle_tile.dart' not in s:
    s = s.replace("import 'package:stellar_pos/core/providers/general_settings_provider.dart';\n", "import 'package:stellar_pos/core/providers/general_settings_provider.dart';\nimport 'package:stellar_pos/presentation/widgets/settings_toggle_tile.dart';\n", 1)
start = s.index('  Widget _switchTile(')
end = s.index('\n  }\n}\n\nclass _PrinterContent', start) + len('\n  }')
s = s[:start] + '''  Widget _switchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SettingsToggleTile(title: title, subtitle: subtitle, value: value, onChanged: onChanged, icon: Icons.inventory_2_outlined);
  }''' + s[end:]
p.write_text(s, encoding='utf-8')

# Printer: same control for auto-print.
p = ROOT / 'lib/presentation/settings/printer_settings_layout_legacy.dart'
s = p.read_text(encoding='utf-8')
if 'settings_toggle_tile.dart' not in s:
    s = s.replace("import 'package:stellar_pos/presentation/widgets/app_alert.dart';\n", "import 'package:stellar_pos/presentation/widgets/app_alert.dart';\nimport 'package:stellar_pos/presentation/widgets/settings_toggle_tile.dart';\n", 1)
marker = s.index("'Imprimir al crear una venta'")
start = s.rfind('          Container(', 0, marker)
end = s.index('          const SizedBox(height: 12),\n          Row(\n            children: [', marker)
s = s[:start] + '''          SettingsToggleTile(
            title: 'Imprimir al crear una venta',
            subtitle: 'Imprime automáticamente el ticket al completar la venta.',
            value: printer.printAutomaticallyOnSale,
            onChanged: printer.setPrintAutomaticallyOnSale,
            icon: Icons.print_rounded,
          ),
''' + s[end:]
p.write_text(s, encoding='utf-8')

# Sales history: reuse the system search bar and the shared detail dialog.
p = ROOT / 'lib/presentation/sales/sales_layout.dart'
s = p.read_text(encoding='utf-8')
s = s.replace("import 'dart:convert';\n\n", '', 1)
if 'sale_detail_dialog.dart' not in s:
    s = s.replace("import 'package:stellar_pos/presentation/widgets/app_alert.dart';\n", "import 'package:stellar_pos/presentation/widgets/app_alert.dart';\nimport 'package:stellar_pos/presentation/dashboard/widgets/sale_detail_dialog.dart';\nimport 'package:stellar_pos/presentation/widgets/product_search_bar.dart';\n", 1)
old = "      Expanded(child: TextField(controller: _searchController, decoration: InputDecoration(hintText: 'Buscar venta, cliente, producto o código...', prefixIcon: const Icon(Icons.search, size: 20), isDense: true, filled: true, fillColor: AppColors.cardBackground, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border))))),"
new = "      Expanded(child: ProductSearchBar(controller: _searchController, hintText: 'Buscar venta, cliente, producto o código...', onChanged: (_) {})),"
assert old in s
s = s.replace(old, new, 1)
start = s.index('  Future<void> _showDetails(')
end = s.index('  Future<void> _printSale(', start)
s = s[:start] + '''  Future<void> _showDetails(SaleRecord sale, double paid) async {
    await SaleDetailDialog.show(context, sale: sale, paidAmount: paid, onPrint: () => _printSale(sale));
  }

''' + s[end:]
p.write_text(s, encoding='utf-8')

# Shared detail: add thumbnails and current credit-payment totals.
p = ROOT / 'lib/presentation/dashboard/widgets/sale_detail_dialog.dart'
s = p.read_text(encoding='utf-8')
if "import 'dart:convert';" not in s:
    s = "import 'dart:convert';\n\n" + s
if 'final double? paidAmount;' not in s:
    s = s.replace('  final Future<bool> Function() onPrint;\n', '  final Future<bool> Function() onPrint;\n  final double? paidAmount;\n', 1)
    s = s.replace('    required this.onPrint,\n', '    required this.onPrint,\n    this.paidAmount,\n', 1)
    s = s.replace('    required Future<bool> Function() onPrint,\n  }) {', '    required Future<bool> Function() onPrint,\n    double? paidAmount,\n  }) {', 1)
    s = s.replace('        child: SaleDetailDialog(sale: sale, onPrint: onPrint),', '        child: SaleDetailDialog(sale: sale, onPrint: onPrint, paidAmount: paidAmount),', 1)
    anchor = '  String _formatTime(DateTime value) {'
    idx = s.index(anchor)
    s = s[:idx] + "  double get _paid => (paidAmount ?? sale.received).clamp(0, sale.total).toDouble();\n  double get _initialPayment => sale.received.clamp(0, sale.total).toDouble();\n  double get _laterPayment => (_paid - _initialPayment).clamp(0, double.infinity).toDouble();\n  double get _pending => (sale.total - _paid).clamp(0, double.infinity).toDouble();\n\n" + s[idx:]
old = "                SizedBox(width: 35, child: Text('Cant.', style: AppTextStyles.ticketLabel)),\n                Expanded(child: Text('Descripción', style: AppTextStyles.ticketLabel)),"
new = "                SizedBox(width: 35, child: Text('Cant.', style: AppTextStyles.ticketLabel)),\n                SizedBox(width: 42, child: Text('Img.', style: AppTextStyles.ticketLabel)),\n                Expanded(child: Text('Descripción', style: AppTextStyles.ticketLabel)),"
if old in s:
    s = s.replace(old, new, 1)
old = "                  SizedBox(width: 35, child: Text('${item.quantity}', style: AppTextStyles.ticketValue)),\n                  Expanded("
new = "                  SizedBox(width: 35, child: Text('${item.quantity}', style: AppTextStyles.ticketValue)),\n                  _thumbnail(item.imageData),\n                  const SizedBox(width: 10),\n                  Expanded("
if old in s:
    s = s.replace(old, new, 1)
if 'Widget _thumbnail(String value)' not in s:
    anchor = '  Widget _buildTotals() {'
    idx = s.index(anchor)
    thumb = '''  Widget _thumbnail(String value) {
    if (value.trim().isNotEmpty) {
      try {
        final raw = value.contains(',') ? value.substring(value.indexOf(',') + 1) : value;
        final bytes = base64Decode(raw);
        return Container(
          width: 42,
          height: 42,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(7), border: Border.all(color: AppColors.border)),
          child: Image.memory(bytes, fit: BoxFit.cover),
        );
      } catch (_) {}
    }
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(7), border: Border.all(color: AppColors.border)),
      child: const Icon(Icons.image_outlined, size: 19, color: AppColors.textMuted),
    );
  }

'''
    s = s[:idx] + thumb + s[idx:]
old = "          _infoRow('Forma de pago', sale.paymentMethod),\n          if (sale.paymentMethod.toUpperCase() == 'EFECTIVO') ...[\n            _summaryRow('Recibido', sale.received),\n            _summaryRow('Cambio', sale.change),\n          ],"
new = "          _infoRow('Forma de pago', sale.paymentMethod),\n          if (sale.paymentMethod == AppStrings.creditPayment) ...[\n            _summaryRow('Pago inicial', _initialPayment),\n            _summaryRow('Abonos posteriores', _laterPayment),\n            _summaryRow('Total cobrado', _paid),\n            _summaryRow('Saldo pendiente', _pending),\n          ] else if (sale.paymentMethod == AppStrings.cashPayment) ...[\n            _summaryRow('Recibido', sale.received),\n            _summaryRow('Cambio', sale.change),\n          ],"
if old in s:
    s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')

# Purchases: keep the existing implementation as legacy and add a page header wrapper.
purchases = ROOT / 'lib/presentation/purchases/purchases_layout.dart'
legacy = ROOT / 'lib/presentation/purchases/purchases_layout_legacy.dart'
if not legacy.exists():
    shutil.copy2(purchases, legacy)
purchases.write_text('''import \'package:flutter/material.dart\';
import \'package:stellar_pos/core/constants/app_constants.dart\';
import \'purchases_layout_legacy.dart\' as legacy;

class PurchasesLayout extends StatelessWidget {
  const PurchasesLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppDimensions.pagePadding, AppDimensions.pagePadding, AppDimensions.pagePadding, 0),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Compras', style: AppTextStyles.brandTitle),
                    SizedBox(height: 3),
                    Text('Historial y registro de las compras realizadas.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(AppDimensions.searchFieldRadius), border: Border.all(color: AppColors.border)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.shopping_bag_outlined, size: 17, color: AppColors.textSecondary), SizedBox(width: 8), Text('Registro de compras', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))]),
              ),
            ],
          ),
        ),
        const Expanded(child: legacy.PurchasesLayout()),
      ],
    );
  }
}
''', encoding='utf-8')
