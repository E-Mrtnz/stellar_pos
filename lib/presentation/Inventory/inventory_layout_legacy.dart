import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/product.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';
import 'package:stellar_pos/core/providers/general_settings_provider.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';
import 'package:stellar_pos/core/providers/providers_provider.dart';
import 'package:stellar_pos/core/services/inventory_file_service.dart';
import 'package:stellar_pos/core/utils/product_filter_utils.dart';
import 'package:stellar_pos/core/utils/product_utils.dart';
import 'package:stellar_pos/presentation/Inventory/widgets/create_product_dialog.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/metric_card.dart';
import 'package:stellar_pos/presentation/inventory/widgets/create_catalog_dialog.dart';
import 'package:stellar_pos/presentation/widgets/product_filter_bar.dart';
import 'package:stellar_pos/presentation/widgets/product_search_bar.dart';

class InventoryLayout extends StatefulWidget {
  const InventoryLayout({super.key});

  @override
  State<InventoryLayout> createState() => _InventoryLayoutState();
}

class _InventoryLayoutState extends State<InventoryLayout> {
  int _selectedTagIndex = 0;
  String? _selectedFilter = 'all';
  String _searchQuery = '';
  bool _isImporting = false;
  bool _isExporting = false;

  List<String> get _tags => context.watch<CatalogProvider>().tags;

  List<Map<String, dynamic>> _filterProducts(
    List<Map<String, dynamic>> products,
  ) {
    return ProductFilterUtils.apply(
      products: products,
      searchQuery: _searchQuery,
      selectedFilter: _selectedFilter,
      tags: _tags,
      selectedTagIndex: _selectedTagIndex,
    );
  }

  Future<void> _createProduct() async => CreateProductDialog.show(context);
  Future<void> _createCatalogItem() async => CreateCatalogDialog.show(context);
  Future<void> _editProduct(Map<String, dynamic> product) async =>
      CreateProductDialog.show(context, product: product);

  Future<void> _importInventory() async {
    if (_isImporting) return;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xlsm'],
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty || !mounted) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showFileMessage(
        'No se pudo leer el archivo seleccionado.',
        title: 'Importación',
      );
      return;
    }

    setState(() => _isImporting = true);

    try {
      final extension = _fileExtension(file.name);
      final parsed = await InventoryFileService.parseExcel(
        Uint8List.fromList(bytes),
        extension,
      );

      if (!mounted) return;

      if (parsed.products.isEmpty) {
        _showFileMessage(
          parsed.errors.isEmpty
              ? 'No se encontraron productos para importar.'
              : parsed.errors.join('\n'),
          title: 'No se importó el inventario',
        );
        return;
      }

      final importResult = _applyImportedProducts(parsed.products);
      final warningMessage = parsed.errors.isEmpty
          ? 'Todos los registros válidos fueron procesados correctamente.'
          : 'Filas omitidas:\n${parsed.errors.join('\n')}';

      _showFileMessage(
        warningMessage,
        title: parsed.errors.isEmpty
            ? 'Inventario importado'
            : 'Importación completada con avisos',
        added: importResult.added,
        updated: importResult.updated,
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  _ImportCounters _applyImportedProducts(List<Product> imported) {
    final productProvider = context.read<ProductProvider>();
    final catalogProvider = context.read<CatalogProvider>();
    final providersProvider = context.read<ProvidersProvider>();

    var added = 0;
    var updated = 0;

    final existing = List<Product>.from(productProvider.products);

    for (final product in imported) {
      if (product.category.trim().isNotEmpty) {
        catalogProvider.addTag(product.category);
      }
      if (product.department.trim().isNotEmpty) {
        providersProvider.addDistributor(product.department);
      }

      final match = _findExistingProduct(existing, product);
      if (match == null) {
        productProvider.addProduct(product);
        existing.add(product);
        added++;
      } else {
        final updatedProduct = product.copyWith(
          id: match.id,
          imageData: match.imageData,
        );
        productProvider.updateProduct(updatedProduct);
        final index = existing.indexWhere((item) => item.id == match.id);
        if (index >= 0) existing[index] = updatedProduct;
        updated++;
      }
    }

    return _ImportCounters(added: added, updated: updated);
  }

  Product? _findExistingProduct(List<Product> products, Product incoming) {
    if (incoming.id.trim().isNotEmpty) {
      for (final product in products) {
        if (product.id == incoming.id.trim()) return product;
      }
    }

    final barcode = incoming.barcode.trim();
    if (barcode.isNotEmpty) {
      for (final product in products) {
        if (product.barcode.trim() == barcode) return product;
      }
    }

    final name = incoming.name.trim().toLowerCase();
    for (final product in products) {
      if (product.name.trim().toLowerCase() == name) return product;
    }

    return null;
  }

  Future<void> _exportExcel() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      await InventoryFileService.saveExcel(
        context.read<ProductProvider>().products,
      );
      if (mounted) {
        _showFileMessage(
          'El inventario se exportó correctamente en formato Excel.',
          title: 'Exportación completada',
        );
      }
    } catch (error) {
      if (mounted) {
        _showFileMessage(
          'No se pudo exportar el inventario.\n$error',
          title: 'Error al exportar',
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPdf() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      await InventoryFileService.savePdf(
        context.read<ProductProvider>().products,
      );
      if (mounted) {
        _showFileMessage(
          'El inventario se exportó correctamente en formato PDF.',
          title: 'Exportación completada',
        );
      }
    } catch (error) {
      if (mounted) {
        _showFileMessage(
          'No se pudo exportar el inventario.\n$error',
          title: 'Error al exportar',
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showFileMessage(
    String message, {
    required String title,
    int? added,
    int? updated,
  }) {
    final isError = title.toLowerCase().contains('error') ||
        title.toLowerCase().contains('no se importó');
    final isImportResult = added != null && updated != null;
    final icon = isError
        ? Icons.error_outline_rounded
        : isImportResult
            ? Icons.inventory_2_outlined
            : Icons.check_circle_outline_rounded;
    final iconColor = isError ? AppColors.dangerRed : AppColors.successGreen;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (isImportResult) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildImportStat(
                          icon: Icons.add_circle_outline,
                          label: 'Agregados',
                          value: '$added',
                          iconColor: AppColors.successGreen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildImportStat(
                          icon: Icons.sync_rounded,
                          label: 'Actualizados',
                          value: '$updated',
                          iconColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.chipBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Aceptar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImportStat({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fileExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>().productMaps;
    final filteredProducts = _filterProducts(products);
    final totalInvestment = products.fold<double>(
      0,
      (total, product) =>
          total + ProductUtils.cost(product) * ProductUtils.stock(product),
    );
    final totalSales = products.fold<double>(
      0,
      (total, product) =>
          total + ProductUtils.price(product) * ProductUtils.stock(product),
    );
    final totalProfit = totalSales - totalInvestment;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopHeader(
                  totalInvestment,
                  totalSales,
                  totalProfit,
                  products.length,
                ),
                const SizedBox(height: 10),
                _buildFileActions(),
                const SizedBox(height: 12),
                ProductFilterBar(
                  tags: _tags,
                  selectedFilter: _selectedFilter,
                  onFilterChanged: (filter) =>
                      setState(() => _selectedFilter = filter),
                  selectedTagIndex: _selectedTagIndex,
                  onTagSelected: (index) =>
                      setState(() => _selectedTagIndex = index),
                ),
                const SizedBox(height: 12),
                Expanded(child: _buildInventoryTable(filteredProducts)),
              ],
            ),
          ),
          _buildFloatingActions(),
        ],
      ),
    );
  }

  Widget _buildTopHeader(
    double totalInvestment,
    double totalSales,
    double totalProfit,
    int productCount,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ProductSearchBar(
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        const SizedBox(width: 12),
        MetricCard(
          amount: productCount.toString(),
          label: 'Productos',
          color: const Color(0xFFF59E0B),
          icon: Icons.inventory_2_outlined,
        ),
        const SizedBox(width: 8),
        MetricCard(
          amount: ProductUtils.money(totalInvestment),
          label: 'Inversión total',
          color: AppColors.dangerRed,
          icon: Icons.payment_outlined,
          iconRotation: 3.141592653589793,
          paymentArrow: true,
        ),
        const SizedBox(width: 8),
        MetricCard(
          amount: ProductUtils.money(totalSales),
          label: 'Ingreso estimado',
          color: AppColors.primary,
          icon: Icons.payment_outlined,
          paymentArrow: true,
        ),
        const SizedBox(width: 8),
        MetricCard(
          amount: ProductUtils.money(totalProfit),
          label: 'Ganancia estimada',
          color: AppColors.successGreen,
          icon: Icons.account_balance_wallet_outlined,
        ),
      ],
    );
  }

  Widget _buildFileActions() {
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

  Widget _buildInventoryTable(List<Map<String, dynamic>> products) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          const Divider(height: 1, color: AppColors.border),
          Expanded(child: _buildInventoryList(products)),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 40),
          SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              AppStrings.inventoryProductHeader,
              style: AppTextStyles.inventoryHeader,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              AppStrings.inventoryCostHeader,
              style: AppTextStyles.inventoryHeader,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              AppStrings.inventorySalePriceHeader,
              style: AppTextStyles.inventoryHeader,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              AppStrings.inventoryStockHeader,
              style: AppTextStyles.inventoryHeader,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              AppStrings.inventoryProfitHeader,
              style: AppTextStyles.inventoryHeader,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              AppStrings.inventoryMarginHeader,
              style: AppTextStyles.inventoryHeader,
            ),
          ),
          SizedBox(
            width: 45,
            child: Text('Editar', style: AppTextStyles.inventoryHeader),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryList(List<Map<String, dynamic>> products) {
    if (products.isEmpty) {
      return const Center(
        child: Text(
          AppStrings.inventoryEmptyMessage,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: products.length,
      separatorBuilder: (_, __) =>
          const Divider(color: AppColors.chipBackground),
      itemBuilder: (context, index) => _buildInventoryRow(products[index]),
    );
  }

  Widget _buildInventoryRow(Map<String, dynamic> product) {
    final cost = ProductUtils.cost(product);
    final price = ProductUtils.price(product);
    final stock = ProductUtils.stock(product);
    final profit = ProductUtils.profit(product);
    final profitPercent =
        ProductUtils.profitPercentage(product).toStringAsFixed(0);
    final name = ProductUtils.cleanName(product);
    final imageData = ProductUtils.asString(product['imageData']);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _buildInventoryImage(imageData),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              ProductUtils.money(cost),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              ProductUtils.money(price),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '$stock',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              ProductUtils.money(profit),
              style: const TextStyle(
                color: AppColors.successGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '$profitPercent%',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          SizedBox(
            width: 45,
            child: IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.primary,
              onPressed: () => _editProduct(product),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryImage(String imageData) {
    if (imageData.isNotEmpty) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(imageData),
            width: AppDimensions.inventoryImageSize,
            height: AppDimensions.inventoryImageSize,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {}
    }

    return Container(
      width: AppDimensions.inventoryImageSize,
      height: AppDimensions.inventoryImageSize,
      decoration: BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image_outlined, color: AppColors.textMuted),
    );
  }

  Widget _buildFloatingActions() {
    return Positioned(
      right: 20,
      bottom: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCircularFab(
            heroTag: 'fab_tags',
            tooltip: AppStrings.createTagsTooltip,
            icon: Icons.label_outlined,
            onPressed: _createCatalogItem,
          ),
          const SizedBox(height: 12),
          _buildCircularFab(
            heroTag: 'fab_products',
            tooltip: AppStrings.createProductsTooltip,
            icon: Icons.inventory_2_outlined,
            onPressed: _createProduct,
          ),
        ],
      ),
    );
  }

  Widget _buildCircularFab({
    required String heroTag,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return FloatingActionButton(
      heroTag: heroTag,
      tooltip: tooltip,
      onPressed: onPressed,
      elevation: AppDimensions.inventoryFabElevation,
      shape: const CircleBorder(),
      backgroundColor: AppColors.primary,
      child: Icon(icon, color: Colors.white, size: AppSizes.iconLarge),
    );
  }
}

class _ImportCounters {
  final int added;
  final int updated;

  const _ImportCounters({required this.added, required this.updated});
}
