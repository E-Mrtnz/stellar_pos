import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/client.dart';
import 'package:stellar_pos/core/models/debt.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';
import 'package:stellar_pos/core/providers/debt_provider.dart';
import 'package:stellar_pos/core/providers/sales_provider.dart';
import 'package:stellar_pos/presentation/Inventory/widgets/create_client_dialog.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/numeric_keypad.dart';
import 'package:stellar_pos/presentation/debts/client_purchase_history_dialog.dart';
import 'package:stellar_pos/presentation/widgets/app_alert.dart';
import 'package:stellar_pos/presentation/widgets/product_search_bar.dart';

class DebtsLayout extends StatefulWidget {
  const DebtsLayout({super.key});

  @override
  State<DebtsLayout> createState() => _DebtsLayoutState();
}

class _DebtsLayoutState extends State<DebtsLayout> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _DebtFilter _filter = _DebtFilter.pending;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createClient() async {
    await CreateClientDialog.show(context);
  }

  Future<void> _editClient(Client client) async {
    final nameController = TextEditingController(text: client.name);
    final phoneController = TextEditingController(text: client.phone);
    final addressController = TextEditingController(text: client.address);

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Editar cliente'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, autofocus: true, decoration: const InputDecoration(labelText: 'Nombre')),
                const SizedBox(height: 12),
                TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono')),
                const SizedBox(height: 12),
                TextField(controller: addressController, keyboardType: TextInputType.streetAddress, maxLines: 2, decoration: const InputDecoration(labelText: 'Dirección')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final updated = Client(
                  id: client.id,
                  name: nameController.text,
                  phone: phoneController.text,
                  address: addressController.text,
                );
                final saved = context.read<CatalogProvider>().updateClient(updated);
                if (!saved) {
                  AppAlert.show(
                    context,
                    'No se pudo actualizar el cliente.',
                    title: 'Error al actualizar',
                    type: AppAlertType.error,
                  );
                  return;
                }
                context.read<DebtProvider>().renameClient(client.id, updated.name.trim());
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
    } finally {
      nameController.dispose();
      phoneController.dispose();
      addressController.dispose();
    }
  }

  Future<void> _addPayment(Client client, DebtAccount account) async {
    if (account.remaining <= 0.005) return;

    final received = await _PaymentDialog.show(
      context,
      clientName: client.name,
      debt: account.remaining,
    );
    if (received == null || !mounted) return;

    final saved = context.read<DebtProvider>().recordPayment(
          clientId: client.id,
          clientName: client.name,
          amount: received,
        );

    if (!saved) {
      AppAlert.show(
        context,
        'No se pudo registrar el abono.',
        title: 'Error al registrar',
        type: AppAlertType.error,
      );
      return;
    }

    final applied = received > account.remaining ? account.remaining : received;
    final change = received > account.remaining ? received - account.remaining : 0.0;
    final message = change > 0.005
        ? 'Se registró un abono de ${_money(applied)}. Cambio: ${_money(change)}.'
        : 'Se registró un abono de ${_money(applied)}.';

    AppAlert.show(
      context,
      message,
      title: 'Abono registrado',
      type: AppAlertType.success,
    );
  }

  Future<void> _showPurchaseHistory(Client client, List<SaleRecord> sales) async {
    await ClientPurchaseHistoryDialog.show(
      context,
      clientName: client.name,
      sales: sales,
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final debtProvider = context.watch<DebtProvider>();
    final salesProvider = context.watch<SalesProvider>();
    final clients = _filteredClients(catalog.clients, debtProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            child: Column(
              children: [
                _buildSummary(debtProvider),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildClientsPanel(clients, debtProvider, salesProvider),
                      ),
                      const SizedBox(width: 12),
                      Expanded(flex: 1, child: _buildHistoryPanel(debtProvider)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton(
              heroTag: 'fab_debt_clients',
              tooltip: 'Crear cliente',
              onPressed: _createClient,
              backgroundColor: AppColors.primary,
              shape: const CircleBorder(),
              child: const Icon(Icons.person_add_alt_1_outlined, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(DebtProvider provider) {
    return Row(
      children: [
        Expanded(child: _SummaryCard(label: 'Deuda pendiente', value: _money(provider.totalRemaining), icon: Icons.account_balance_wallet_outlined, color: AppColors.dangerRed)),
        const SizedBox(width: 10),
        Expanded(child: _SummaryCard(label: 'Total abonado', value: _money(provider.totalPaid), icon: Icons.payments_outlined, color: AppColors.successGreen)),
        const SizedBox(width: 10),
        Expanded(child: _SummaryCard(label: 'Clientes con deuda', value: provider.clientsWithDebt.toString(), icon: Icons.people_outline, color: AppColors.primary)),
      ],
    );
  }

  Widget _buildClientsPanel(List<Client> clients, DebtProvider debtProvider, SalesProvider salesProvider) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Clientes', style: AppTextStyles.sectionTitle),
              const Spacer(),
              Text('${clients.length}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ProductSearchBar(
                  controller: _searchController,
                  hintText: 'Buscar cliente...',
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButtonHideUnderline(
                child: DropdownButton<_DebtFilter>(
                  value: _filter,
                  borderRadius: BorderRadius.circular(10),
                  items: const [
                    DropdownMenuItem(value: _DebtFilter.all, child: Text('Todos')),
                    DropdownMenuItem(value: _DebtFilter.pending, child: Text('Con deuda')),
                    DropdownMenuItem(value: _DebtFilter.paid, child: Text('Pagados')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _filter = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: clients.isEmpty
                ? const _EmptyState(icon: Icons.people_outline, message: 'No hay clientes que coincidan con el filtro.')
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 70),
                    itemCount: clients.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final client = clients[index];
                      final account = debtProvider.accountFor(client.id) ?? DebtAccount(clientId: client.id, clientName: client.name, totalDebt: 0, totalPaid: 0);
                      final clientSales = salesProvider.sales.where((sale) => sale.clientId == client.id && sale.paymentMethod.toLowerCase() == 'fiado').toList(growable: false);
                      return _ClientDebtCard(
                        client: client,
                        account: account,
                        purchaseCount: clientSales.length,
                        onEdit: () => _editClient(client),
                        onHistory: () => _showPurchaseHistory(client, clientSales),
                        onPayment: account.remaining > 0.005 ? () => _addPayment(client, account) : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryPanel(DebtProvider provider) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.history, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 7),
              const Text('Historial', style: AppTextStyles.sectionTitle),
              const Spacer(),
              Text('${provider.movements.length}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: provider.movements.isEmpty
                ? const _EmptyState(icon: Icons.receipt_long_outlined, message: 'Todavía no hay movimientos.')
                : ListView.separated(
                    itemCount: provider.movements.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 7),
                    itemBuilder: (_, index) => _MovementTile(provider.movements[index]),
                  ),
          ),
        ],
      ),
    );
  }

  List<Client> _filteredClients(List<Client> clients, DebtProvider provider) {
    final query = _searchQuery.trim().toLowerCase();
    final result = clients.where((client) {
      if (query.isNotEmpty && !client.name.toLowerCase().contains(query) && !client.phone.toLowerCase().contains(query)) return false;
      final account = provider.accountFor(client.id);
      final remaining = account?.remaining ?? 0;
      if (_filter == _DebtFilter.pending && remaining <= 0.005) return false;
      if (_filter == _DebtFilter.paid && (account == null || remaining > 0.005)) return false;
      return true;
    }).toList();

    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  String _money(double value) => '\$${value.toStringAsFixed(2)}';
}

enum _DebtFilter { all, pending, paid }

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withAlpha(18), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 21)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientDebtCard extends StatelessWidget {
  final Client client;
  final DebtAccount account;
  final int purchaseCount;
  final VoidCallback onEdit;
  final VoidCallback onHistory;
  final VoidCallback? onPayment;

  const _ClientDebtCard({required this.client, required this.account, required this.purchaseCount, required this.onEdit, required this.onHistory, required this.onPayment});

  @override
  Widget build(BuildContext context) {
    final paid = account.totalPaid;
    final remaining = account.remaining;
    final progress = account.paidPercentage;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 10, 10),
      decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.primary.withAlpha(18), shape: BoxShape.circle), child: const Icon(Icons.person_outline, size: 19, color: AppColors.primary)),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    if (client.phone.isNotEmpty) Text(client.phone, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ),
              if (purchaseCount > 0)
                TextButton.icon(
                  onPressed: onHistory,
                  icon: const Icon(Icons.receipt_long_outlined, size: 15),
                  label: Text('$purchaseCount compras'),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 7), visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 10)),
                ),
              IconButton(tooltip: 'Editar', onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 17), color: AppColors.textSecondary, visualDensity: VisualDensity.compact),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(child: _AmountBox(label: 'Deuda', value: _money(account.totalDebt), color: AppColors.dangerRed)),
              const SizedBox(width: 7),
              Expanded(child: _AmountBox(label: 'Abonado', value: _money(paid), color: AppColors.successGreen)),
              const SizedBox(width: 7),
              Expanded(child: _AmountBox(label: 'Restante', value: _money(remaining), color: remaining > 0.005 ? AppColors.warningOrange : AppColors.successGreen)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: AppColors.border, valueColor: const AlwaysStoppedAnimation<Color>(AppColors.successGreen)))),
              const SizedBox(width: 8),
              Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: onPayment,
              icon: const Icon(Icons.payments_outlined, size: 16),
              label: const Text('Abonar'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 12), textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  String _money(double value) => '\$${value.toStringAsFixed(2)}';
}

class _AmountBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _AmountBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)), const SizedBox(height: 2), Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color))]),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final DebtMovement movement;
  const _MovementTile(this.movement);

  @override
  Widget build(BuildContext context) {
    final isPayment = movement.type == DebtMovementType.payment;
    final color = isPayment ? AppColors.successGreen : AppColors.dangerRed;
    final label = isPayment ? 'Abono' : 'Nueva deuda';
    final sign = isPayment ? '-' : '+';
    final date = '${movement.createdAt.day.toString().padLeft(2, '0')}/${movement.createdAt.month.toString().padLeft(2, '0')}/${movement.createdAt.year}';
    final hour = movement.createdAt.hour % 12 == 0 ? 12 : movement.createdAt.hour % 12;
    final period = movement.createdAt.hour >= 12 ? 'PM' : 'AM';
    final time = '${hour.toString().padLeft(2, '0')}:${movement.createdAt.minute.toString().padLeft(2, '0')} $period';

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: color.withAlpha(8), borderRadius: BorderRadius.circular(9), border: Border.all(color: color.withAlpha(30))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 27, height: 27, decoration: BoxDecoration(color: color.withAlpha(18), shape: BoxShape.circle), child: Icon(isPayment ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 15, color: color)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(movement.clientName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)), const SizedBox(height: 2), Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text('$date · $time', style: const TextStyle(fontSize: 9, color: AppColors.textMuted)), if (movement.reference != null && movement.reference!.isNotEmpty) Text('Ticket #${movement.reference}', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary))]),
          ),
          Text('$sign\$${movement.amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _DialogBalanceRow extends StatelessWidget {
  final String label;
  final String value;
  const _DialogBalanceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)), const Spacer(), Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.dangerRed))]);
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 30, color: AppColors.textMuted), const SizedBox(height: 8), Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.textMuted))]));
  }
}

class _PaymentDialog extends StatefulWidget {
  final String clientName;
  final double debt;

  const _PaymentDialog({required this.clientName, required this.debt});

  static Future<double?> show(
    BuildContext context, {
    required String clientName,
    required double debt,
  }) {
    return showDialog<double>(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (_) => Dialog(
        backgroundColor: AppColors.cardBackground,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: _PaymentDialog(clientName: clientName, debt: debt),
        ),
      ),
    );
  }

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey _dialogKey = GlobalKey();
  final Object _keypadGroup = Object();
  OverlayEntry? _keypadEntry;
  Offset _keypadPosition = Offset.zero;

  double get _received => double.tryParse(_controller.text.replaceAll(',', '.')) ?? 0;
  double get _change => (_received - widget.debt).clamp(0, double.infinity).toDouble();

  @override
  void dispose() {
    _keypadEntry?.remove();
    _keypadEntry = null;
    _controller.dispose();
    super.dispose();
  }

  void _showKeypad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateKeypadPosition();
      if (_keypadEntry == null) {
        final overlay = Overlay.of(context, rootOverlay: true);
        _keypadEntry = OverlayEntry(
          builder: (_) => Positioned(
            left: _keypadPosition.dx,
            top: _keypadPosition.dy,
            width: NumericKeypad.width,
            height: NumericKeypad.height,
            child: TapRegion(
              groupId: _keypadGroup,
              child: Focus(
                canRequestFocus: false,
                skipTraversal: true,
                child: NumericKeypad(
                  onInput: _input,
                  onBackspace: _backspace,
                  onClear: _clear,
                  onDecimal: _decimal,
                ),
              ),
            ),
          ),
        );
        overlay.insert(_keypadEntry!);
      } else {
        _keypadEntry!.markNeedsBuild();
      }
    });
  }

  void _updateKeypadPosition() {
    final renderObject = _dialogKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    final screen = MediaQuery.sizeOf(context);
    final rightLeft = topLeft.dx + size.width + 8;
    final leftLeft = topLeft.dx - NumericKeypad.width - 8;
    final centeredTop = topLeft.dy + (size.height - NumericKeypad.height) / 2;
    final maxLeft = screen.width - NumericKeypad.width - 8;
    final maxTop = screen.height - NumericKeypad.height - 8;
    double left;
    double top = centeredTop;
    if (rightLeft + NumericKeypad.width <= screen.width - 8) {
      left = rightLeft;
    } else if (leftLeft >= 8) {
      left = leftLeft;
    } else {
      left = rightLeft.clamp(8, maxLeft < 8 ? 8 : maxLeft);
      top = topLeft.dy + size.height + 8;
    }
    _keypadPosition = Offset(
      left.clamp(8, maxLeft < 8 ? 8 : maxLeft),
      top.clamp(8, maxTop < 8 ? 8 : maxTop),
    );
  }

  void _closeKeypad() {
    _keypadEntry?.remove();
    _keypadEntry = null;
  }

  void _setText(String value) {
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() {});
  }

  void _input(String digit) => _setText('${_controller.text}$digit');

  void _decimal() {
    if (_controller.text.contains('.')) return;
    _setText(_controller.text.isEmpty ? '0.' : '${_controller.text}.');
  }

  void _backspace() {
    if (_controller.text.isEmpty) return;
    _setText(_controller.text.substring(0, _controller.text.length - 1));
  }

  void _clear() => _setText('');

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _keypadGroup,
      onTapOutside: (_) => _closeKeypad(),
      child: Padding(
        key: _dialogKey,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withAlpha(16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.payments_outlined, color: AppColors.successGreen, size: 21),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Abonar a ${widget.clientName}', style: AppTextStyles.sectionTitle),
                      const SizedBox(height: 2),
                      const Text('Registra el efectivo recibido y calcula el cambio.', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, size: 19)),
              ],
            ),
            const SizedBox(height: 14),
            _DialogBalanceRow(label: 'Deuda pendiente', value: '\$${widget.debt.toStringAsFixed(2)}'),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onTap: _showKeypad,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Efectivo recibido',
                prefixText: '\$ ',
                prefixIcon: Icon(Icons.payments_outlined, size: 19),
              ),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 140),
              child: _change > 0.005
                  ? Container(
                      key: const ValueKey('change'),
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.warningOrange.withAlpha(12),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppColors.warningOrange.withAlpha(35)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.currency_exchange, size: 17, color: AppColors.warningOrange),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('Cambio a entregar', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                          Text(
                            '\$${_change.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.warningOrange),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(key: ValueKey('no-change'), height: 39),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _received > 0 ? () => Navigator.of(context).pop(_received) : null,
                  icon: const Icon(Icons.check_rounded, size: 17),
                  label: const Text('Registrar abono'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
