import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/product.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/debt_provider.dart';
import 'package:stellar_pos/core/providers/electronic_balance_provider.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';
import 'package:stellar_pos/core/providers/sales_provider.dart';
import 'package:stellar_pos/presentation/widgets/app_alert.dart';

class SaleDetailDialog extends StatelessWidget {
  static ValueChanged<SaleRecord>? editHandler;
  static ValueChanged<SaleRecord>? returnHandler;
  static ValueChanged<SaleRecord>? changeHandler;
  final SaleRecord sale;
  final Future<void> Function() onPrint;
  final double? paidAmount;

  const SaleDetailDialog({
    super.key,
    required this.sale,
    required this.onPrint,
    this.paidAmount,
  });

  static Future<void> show(
    BuildContext context, {
    required SaleRecord sale,
    required Future<void> Function() onPrint,
    double? paidAmount,
  }) {
    return showDialog(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SaleDetailDialog(
          sale: sale,
          onPrint: onPrint,
          paidAmount: paidAmount,
        ),
      ),
    );
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  String _formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')} $period';
  }

  double get _paid => (paidAmount ?? sale.effectiveCollected)
      .clamp(0, sale.effectiveTotal)
      .toDouble();
  double get _initialPayment =>
      sale.received.clamp(0, sale.effectiveTotal).toDouble();
  double get _laterPayment =>
      (_paid - _initialPayment).clamp(0, double.infinity).toDouble();
  double get _pending =>
      (sale.effectiveTotal - _paid).clamp(0, double.infinity).toDouble();

  void _modify(BuildContext context) {
    Navigator.of(context).pop();
    editHandler?.call(sale);
  }

  Future<void> _annul(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Anular venta'),
        content: Text(
          '¿Seguro que deseas anular la venta #${sale.ticketNumber}? La venta permanecerá en el historial y se revertirá el inventario asociado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final annulled = context.read<SalesProvider>().annulSale(
      saleId: sale.id,
      productProvider: context.read<ProductProvider>(),
      electronicBalanceProvider: context.read<ElectronicBalanceProvider>(),
    );
    if (!context.mounted) return;
    if (annulled) {
      context.read<DebtProvider>().syncInitialPayment(
        saleId: sale.id,
        clientId: sale.clientId ?? '',
        clientName: sale.clientName,
        amount: 0,
      );
      Navigator.of(context).pop();
      AppAlert.show(
        context,
        'La venta #${sale.ticketNumber} fue anulada y permanece en el historial.',
        title: 'Venta anulada',
        type: AppAlertType.success,
      );
    } else {
      AppAlert.show(
        context,
        'No se pudo anular la venta.',
        title: 'Error al anular',
        type: AppAlertType.error,
      );
    }
  }

  Future<void> _returnItems(BuildContext context) async {
    if (!sale.canOperateToday) {
      AppAlert.show(
        context,
        'Los cambios y devoluciones solo pueden realizarse el mismo día de la venta.',
        title: 'Operación no disponible',
        type: AppAlertType.warning,
      );
      return;
    }
    final available = context.read<SalesProvider>().availableItemsForOperation(
      sale.id,
    );
    if (available.isEmpty) {
      AppAlert.show(
        context,
        'No quedan productos disponibles para devolver en esta venta.',
        title: 'Sin productos',
        type: AppAlertType.warning,
      );
      return;
    }
    final result = await showDialog<_ReturnSelection>(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (dialogContext) => _ReturnDialog(items: available),
    );
    if (result == null || !context.mounted) return;
    try {
      final updated = context.read<SalesProvider>().returnItems(
        saleId: sale.id,
        quantitiesByProduct: {result.productId: result.quantity},
        productProvider: context.read<ProductProvider>(),
      );
      context.read<DebtProvider>().syncInitialPayment(
        saleId: updated.id,
        clientId: updated.clientId ?? '',
        clientName: updated.clientName,
        amount: updated.effectiveCollected,
      );
      Navigator.of(context).pop();
      AppAlert.show(
        context,
        'Se devolvió ${_money(result.amount)} al cliente y el producto regresó al inventario.',
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

  Future<void> _changeItem(BuildContext context) async {
    if (!sale.canOperateToday) {
      AppAlert.show(
        context,
        'Los cambios y devoluciones solo pueden realizarse el mismo día de la venta.',
        title: 'Operación no disponible',
        type: AppAlertType.warning,
      );
      return;
    }
    final salesProvider = context.read<SalesProvider>();
    final products = context
        .read<ProductProvider>()
        .products
        .where(
          (product) =>
              product.stock > 0 && !product.id.startsWith('electronic:'),
        )
        .toList(growable: false);
    final available = salesProvider.availableItemsForOperation(sale.id);
    if (available.isEmpty || products.isEmpty) {
      AppAlert.show(
        context,
        'No hay productos disponibles para realizar el cambio.',
        title: 'Cambio no disponible',
        type: AppAlertType.warning,
      );
      return;
    }
    final result = await showDialog<_ChangeSelection>(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (dialogContext) =>
          _ChangeDialog(items: available, products: products),
    );
    if (result == null || !context.mounted) return;
    try {
      final updated = salesProvider.changeItem(
        saleId: sale.id,
        sourceProductId: result.sourceProductId,
        quantity: result.quantity,
        replacementProductId: result.replacementProductId,
        productProvider: context.read<ProductProvider>(),
      );
      context.read<DebtProvider>().syncInitialPayment(
        saleId: updated.id,
        clientId: updated.clientId ?? '',
        clientName: updated.clientName,
        amount: updated.effectiveCollected,
      );
      Navigator.of(context).pop();
      final message = result.amountDelta < -0.005
          ? 'Debes devolver ${_money(result.amountDelta.abs())} al cliente.'
          : result.amountDelta > 0.005
          ? 'Debes cobrar ${_money(result.amountDelta)} al cliente.'
          : 'El cambio no genera diferencia de dinero.';
      AppAlert.show(
        context,
        message,
        title: 'Cambio registrado',
        type: AppAlertType.success,
      );
    } catch (error) {
      AppAlert.show(
        context,
        error.toString().replaceFirst('Bad state: ', ''),
        title: 'No se pudo registrar el cambio',
        type: AppAlertType.error,
      );
    }
  }

  String _money(double value) => '\$${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final canOperate = sale.isCompleted && sale.canOperateToday;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
      child: Material(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.dialogRadius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _saleBadge(
                          sale.isAnnulled ? 'ANULADA' : 'COMPLETADA',
                          sale.isAnnulled
                              ? AppColors.dangerRed
                              : AppColors.successGreen,
                        ),
                        for (final type in _operationTypes()) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 5),
                            child: Text(
                              '—',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          _saleBadge(
                            type == SaleOperationType.change
                                ? 'CAMBIO'
                                : 'DEVOLUCIÓN',
                            type == SaleOperationType.change
                                ? AppColors.primary
                                : AppColors.warningOrange,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '#${sale.ticketNumber}',
                    style: AppTextStyles.ticketValue,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 19),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 14),
                    _buildItemsTable(),
                    if (sale.operations.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _buildOperations(),
                    ],
                    const SizedBox(height: 14),
                    _buildTotals(),
                    const SizedBox(height: 14),
                    _buildPaymentInfo(),
                    const SizedBox(height: 14),
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            'Gracias por su compra',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Código de ticket: ${sale.ticketNumber}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  if (canOperate) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              returnHandler?.call(sale);
                            },
                            icon: const Icon(
                              Icons.assignment_return_outlined,
                              size: 17,
                            ),
                            label: const Text('Devolución'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              changeHandler?.call(sale);
                            },
                            icon: const Icon(Icons.swap_horiz, size: 17),
                            label: const Text('Cambio'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ] else if (sale.isCompleted) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Los cambios y devoluciones solo están disponibles el mismo día de la venta.',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _modify(context),
                          icon: const Icon(Icons.edit_outlined, size: 17),
                          label: const Text('Modificar venta'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: sale.isAnnulled
                              ? null
                              : () => _annul(context),
                          icon: const Icon(Icons.block_outlined, size: 17),
                          label: const Text('Anular'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.dangerRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cerrar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async => onPrint(),
                          icon: const Icon(Icons.print_outlined, size: 17),
                          label: const Text('Imprimir ticket'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(38),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<SaleOperationType> _operationTypes() {
    final result = <SaleOperationType>[];
    for (final operation in sale.operations) {
      if (!result.contains(operation.type)) result.add(operation.type);
    }
    return result;
  }

  Widget _saleBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(.10),
      border: Border.all(color: color.withOpacity(.35)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
    ),
  );

  Widget _buildHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'STELLAR POS',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 2),
      const Text(
        'MI TIENDA',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 9),
      _infoRow('N.º de ticket', '#${sale.ticketNumber}'),
      _infoRow('Estado', sale.isAnnulled ? 'ANULADA' : 'COMPLETADA'),
      _infoRow('Fecha', _formatDate(sale.createdAt)),
      _infoRow('Hora', _formatTime(sale.createdAt)),
      _infoRow('Cliente', sale.clientName),
    ],
  );

  Widget _buildItemsTable() => Container(
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: const BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 42,
                child: Text('Img.', style: AppTextStyles.ticketLabel),
              ),
              Expanded(
                child: Text('Descripción', style: AppTextStyles.ticketLabel),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  'Cant.',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.ticketLabel,
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  'P. Unit.',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.ticketLabel,
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  'Dcto.',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.ticketLabel,
                ),
              ),
              SizedBox(
                width: 75,
                child: Text(
                  'Total',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.ticketLabel,
                ),
              ),
            ],
          ),
        ),
        ...sale.items.map((item) {
          final displayUnitPrice = item.hasGroupPricing
              ? item.lineTotal
              : item.unitPrice;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                _thumbnail(item.imageData),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${item.quantity}',
                    textAlign: TextAlign.right,
                    style: AppTextStyles.ticketValue,
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    _money(displayUnitPrice),
                    textAlign: TextAlign.right,
                    style: AppTextStyles.ticketValue,
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    _money(item.discount),
                    textAlign: TextAlign.right,
                    style: AppTextStyles.ticketValue,
                  ),
                ),
                SizedBox(
                  width: 75,
                  child: Text(
                    _money(item.lineTotal),
                    textAlign: TextAlign.right,
                    style: AppTextStyles.ticketValue,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ),
  );

  Widget _buildOperations() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: AppColors.inputBackground,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Operaciones posteriores',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...sale.operations.map(_operationCard),
      ],
    ),
  );

  Widget _operationCard(SaleOperationRecord operation) {
    final color = operation.type == SaleOperationType.change
        ? AppColors.primary
        : AppColors.warningOrange;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _saleBadge(operation.label, color),
              const Spacer(),
              Text(
                '${_formatDate(operation.createdAt)} ${_formatTime(operation.createdAt)}',
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ...operation.itemsOut.map((item) => _operationLine('Sale', item)),
          ...operation.itemsIn.map((item) => _operationLine('Entra', item)),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              operation.amountDelta < -0.005
                  ? 'Devolver ${_money(operation.amountDelta.abs())}'
                  : operation.amountDelta > 0.005
                  ? 'Cobrar ${_money(operation.amountDelta)}'
                  : 'Sin diferencia monetaria',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: operation.amountDelta < -0.005
                    ? AppColors.warningOrange
                    : operation.amountDelta > 0.005
                    ? AppColors.successGreen
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _operationLine(String prefix, SaleItemRecord item) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '$prefix: ${item.productName} × ${item.quantity}',
            style: const TextStyle(fontSize: 10),
          ),
        ),
        Text(
          _money(item.lineTotal),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Widget _thumbnail(String value) {
    if (value.trim().isNotEmpty) {
      try {
        final raw = value.contains(',')
            ? value.substring(value.indexOf(',') + 1)
            : value;
        final bytes = base64Decode(raw);
        return Container(
          width: 42,
          height: 42,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppColors.border),
          ),
          child: Image.memory(bytes, fit: BoxFit.cover),
        );
      } catch (_) {}
    }
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.border),
      ),
      child: const Icon(
        Icons.image_outlined,
        size: 19,
        color: AppColors.textMuted,
      ),
    );
  }

  Widget _buildTotals() => Column(
    children: [
      _summaryRow('Subtotal', sale.subtotal),
      _summaryRow('Descuento', sale.discountAmount),
      if (sale.cardFeeAmount > 0)
        _summaryRow('Cargo tarjeta', sale.cardFeeAmount),
      if (sale.operationDelta.abs() > .005)
        _summaryRow('Ajustes por operaciones', sale.operationDelta),
      const Divider(height: 16, color: AppColors.border),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Total', style: AppTextStyles.totalLabel),
          Text(_money(sale.effectiveTotal), style: AppTextStyles.totalValue),
        ],
      ),
    ],
  );

  Widget _buildPaymentInfo() => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: AppColors.inputBackground,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Column(
      children: [
        _infoRow('Forma de pago', sale.paymentMethod),
        if (sale.paymentMethod == AppStrings.creditPayment) ...[
          _summaryRow('Pago inicial', _initialPayment),
          _summaryRow('Abonos posteriores', _laterPayment),
          _summaryRow('Total cobrado', _paid),
          _summaryRow('Saldo pendiente', _pending),
        ] else if (sale.paymentMethod == AppStrings.cashPayment) ...[
          _summaryRow('Recibido', sale.received),
          _summaryRow('Cambio', sale.change),
        ],
      ],
    ),
  );
  Widget _summaryRow(String label, double value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.ticketLabel),
        Text(_money(value), style: AppTextStyles.ticketValue),
      ],
    ),
  );
  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(
          width: 105,
          child: Text(label, style: AppTextStyles.ticketLabel),
        ),
        Expanded(child: Text(value, style: AppTextStyles.ticketValue)),
      ],
    ),
  );
}

class _ReturnSelection {
  final String productId;
  final int quantity;
  final double amount;
  const _ReturnSelection({
    required this.productId,
    required this.quantity,
    required this.amount,
  });
}

class _ReturnDialog extends StatefulWidget {
  final List<SaleItemRecord> items;
  const _ReturnDialog({required this.items});
  @override
  State<_ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends State<_ReturnDialog> {
  late String _productId;
  final _quantityController = TextEditingController(text: '1');
  @override
  void initState() {
    super.initState();
    _productId = widget.items.first.productId;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  SaleItemRecord get _item =>
      widget.items.firstWhere((item) => item.productId == _productId);
  void _submit() {
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (quantity <= 0 || quantity > _item.quantity) return;
    final amount = _item.quantity <= 0
        ? 0.0
        : _item.lineTotal * quantity / _item.quantity;
    Navigator.pop(
      context,
      _ReturnSelection(
        productId: _productId,
        quantity: quantity,
        amount: amount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Registrar devolución'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Selecciona el producto que el cliente devuelve.'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _productId,
            decoration: const InputDecoration(labelText: 'Producto'),
            items: [
              for (final item in widget.items)
                DropdownMenuItem(
                  value: item.productId,
                  child: Text(
                    '${item.productName} · ${item.quantity} disponibles',
                  ),
                ),
            ],
            onChanged: (value) => setState(() {
              if (value != null) _productId = value;
            }),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Cantidad',
              helperText: 'Máximo: ${_item.quantity}',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Continuar')),
    ],
  );
}

class _ChangeSelection {
  final String sourceProductId;
  final int quantity;
  final String replacementProductId;
  final double amountDelta;
  const _ChangeSelection({
    required this.sourceProductId,
    required this.quantity,
    required this.replacementProductId,
    required this.amountDelta,
  });
}

class _ChangeDialog extends StatefulWidget {
  final List<SaleItemRecord> items;
  final List<Product> products;
  const _ChangeDialog({required this.items, required this.products});
  @override
  State<_ChangeDialog> createState() => _ChangeDialogState();
}

String _moneyValue(double value) => '\$${value.toStringAsFixed(2)}';

class _ChangeDialogState extends State<_ChangeDialog> {
  late String _sourceId;
  late String _replacementId;
  final _quantityController = TextEditingController(text: '1');
  @override
  void initState() {
    super.initState();
    _sourceId = widget.items.first.productId;
    _replacementId = widget.products.first.id;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  SaleItemRecord get _source =>
      widget.items.firstWhere((item) => item.productId == _sourceId);
  Product get _replacement =>
      widget.products.firstWhere((product) => product.id == _replacementId);
  void _submit() {
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (quantity <= 0 ||
        quantity > _source.quantity ||
        _replacement.id == _source.productId)
      return;
    final oldAmount = _source.lineTotal * quantity / _source.quantity;
    final newAmount = _replacement.price * quantity;
    Navigator.pop(
      context,
      _ChangeSelection(
        sourceProductId: _source.productId,
        quantity: quantity,
        replacementProductId: _replacement.id,
        amountDelta: newAmount - oldAmount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Registrar cambio'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selecciona el producto que sale y el producto que entra.',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _sourceId,
            decoration: const InputDecoration(labelText: 'Producto que sale'),
            items: [
              for (final item in widget.items)
                DropdownMenuItem(
                  value: item.productId,
                  child: Text(
                    '${item.productName} · ${item.quantity} disponibles',
                  ),
                ),
            ],
            onChanged: (value) => setState(() {
              if (value != null) _sourceId = value;
            }),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Cantidad',
              helperText: 'Máximo: ${_source.quantity}',
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _replacementId,
            decoration: const InputDecoration(labelText: 'Producto nuevo'),
            items: [
              for (final product in widget.products)
                DropdownMenuItem(
                  value: product.id,
                  child: Text(
                    '${product.name} · ${_moneyValue(product.price)}',
                  ),
                ),
            ],
            onChanged: (value) => setState(() {
              if (value != null) _replacementId = value;
            }),
          ),
          const SizedBox(height: 10),
          Text(
            'Valor nuevo estimado: ${_moneyValue(_replacement.price)} por unidad',
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Continuar')),
    ],
  );
}
