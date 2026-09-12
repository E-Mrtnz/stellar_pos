import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/client.dart';
import 'package:stellar_pos/core/models/client_group.dart';
import 'package:stellar_pos/core/models/debt.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';
import 'package:stellar_pos/core/providers/client_group_provider.dart';
import 'package:stellar_pos/core/providers/debt_provider.dart';
import 'package:stellar_pos/core/providers/sales_provider.dart';
import 'package:stellar_pos/presentation/Inventory/widgets/create_client_dialog.dart';
import 'package:stellar_pos/presentation/Inventory/widgets/create_client_group_dialog.dart';
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
  final Set<String> _expandedGroups = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createClient() => CreateClientDialog.show(context);

  Future<void> _createGroup() async {
    await CreateClientGroupDialog.show(context);
    if (mounted) setState(() {});
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
                  AppAlert.show(context, 'No se pudo actualizar el cliente.', title: 'Error al actualizar', type: AppAlertType.error);
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
    final received = await _PaymentDialog.show(context, clientName: client.name, debt: account.remaining);
    if (received == null || !mounted) return;

    final saved = context.read<DebtProvider>().recordPayment(
      clientId: client.id,
      clientName: client.name,
      amount: received,
    );
    if (!saved) {
      AppAlert.show(context, 'No se pudo registrar el abono.', title: 'Error al registrar', type: AppAlertType.error);
      return;
    }

    final applied = received > account.remaining ? account.remaining : received;
    final change = received > account.remaining ? received - account.remaining : 0.0;
    AppAlert.show(
      context,
      change > 0.005
          ? 'Se registró un abono de ${_money(applied)}. Cambio: ${_money(change)}.'
          : 'Se registró un abono de ${_money(applied)}.',
      title: 'Abono registrado',
      type: AppAlertType.success,
    );
  }

  Future<void> _showPurchaseHistory(Client client, List<SaleRecord> sales) =>
      ClientPurchaseHistoryDialog.show(context, clientName: client.name, sales: sales);

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final debtProvider = context.watch<DebtProvider>();
    final salesProvider = context.watch<SalesProvider>();
    final groupProvider = context.watch<ClientGroupProvider>();
    final groupedClientIds = groupProvider.groups.expand((group) => group.clientIds).toSet();
    final clients = _filteredClients(catalog.clients, debtProvider, groupedClientIds);
    final groups = _filteredGroups(groupProvider.groups, catalog.clients, debtProvider);

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
                      Expanded(flex: 3, child: _buildClientsPanel(clients, groups, debtProvider, salesProvider, catalog.clients)),
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
            bottom: 82,
            child: FloatingActionButton.extended(
              heroTag: 'fab_debt_groups',
              tooltip: 'Crear grupos',
              onPressed: _createGroup,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.groups_outlined),
              label: const Text('Crear grupos'),
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

  Widget _buildClientsPanel(
    List<Client> clients,
    List<ClientGroup> groups,
    DebtProvider debtProvider,
    SalesProvider salesProvider,
    List<Client> allClients,
  ) {
    final visibleCount = clients.length + groups.length;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Clientes', style: AppTextStyles.sectionTitle),
              const Spacer(),
              Text('$visibleCount', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ProductSearchBar(
                  controller: _searchController,
                  hintText: 'Buscar cliente o grupo...',
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
            child: visibleCount == 0
                ? const _EmptyState(icon: Icons.people_outline, message: 'No hay clientes o grupos que coincidan con el filtro.')
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: visibleCount,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      if (index < groups.length) {
                        final group = groups[index];
                        return _buildGroupCard(group, allClients, debtProvider, salesProvider);
                      }
                      final client = clients[index - groups.length];
                      return _buildClientCard(client, debtProvider, salesProvider);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(ClientGroup group, List<Client> allClients, DebtProvider debtProvider, SalesProvider salesProvider) {
    final members = allClients.where((client) => group.clientIds.contains(client.id)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final totalDebt = _groupTotalDebt(members, debtProvider);
    final totalPaid = _groupTotalPaid(members, debtProvider);
    final remaining = (totalDebt - totalPaid).clamp(0, double.infinity).toDouble();
    final expanded = _expandedGroups.contains(group.id);
    final progress = totalDebt <= 0 ? 0.0 : (totalPaid / totalDebt).clamp(0, 1).toDouble();

    return Container(
      decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => expanded ? _expandedGroups.remove(group.id) : _expandedGroups.add(group.id)),
            borderRadius: BorderRadius.circular(11),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 10, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.primary.withAlpha(18), shape: BoxShape.circle), child: const Icon(Icons.groups_outlined, size: 19, color: AppColors.primary)),
                      const SizedBox(width: 9),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(group.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)), Text('${members.length} integrantes', style: const TextStyle(fontSize: 10, color: AppColors.textMuted))])),
                      Text('${_money(remaining)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: remaining > 0.005 ? AppColors.dangerRed : AppColors.successGreen)),
                      const SizedBox(width: 5),
                      Icon(expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(children: [Expanded(child: _AmountBox(label: 'Deuda', value: _money(totalDebt), color: AppColors.dangerRed)), const SizedBox(width: 7), Expanded(child: _AmountBox(label: 'Abonado', value: _money(totalPaid), color: AppColors.successGreen)), const SizedBox(width: 7), Expanded(child: _AmountBox(label: 'Restante', value: _money(remaining), color: remaining > 0.005 ? AppColors.warningOrange : AppColors.successGreen))]),
                  const SizedBox(height: 8),
                  ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, minHeight: 5, backgroundColor: AppColors.border, valueColor: AlwaysStoppedAnimation<Color>(remaining > 0.005 ? AppColors.primary : AppColors.successGreen))),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                children: members.isEmpty
                    ? [const Padding(padding: EdgeInsets.all(12), child: Text('Este grupo no tiene clientes asignados.', style: TextStyle(color: AppColors.textMuted, fontSize: 11)))]
                    : members.map((client) => Padding(padding: const EdgeInsets.only(top: 7), child: _buildClientCard(client, debtProvider, salesProvider, compact: true))).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClientCard(Client client, DebtProvider debtProvider, SalesProvider salesProvider, {bool compact = false}) {
    final account = debtProvider.accountFor(client.id) ?? DebtAccount(clientId: client.id, clientName: client.name, totalDebt: 0, totalPaid: 0);
    final clientSales = salesProvider.sales.where((sale) => sale.clientId == client.id && sale.paymentMethod.toLowerCase() == 'fiado').toList(growable: false);
    return _ClientDebtCard(
      client: client,
      account: account,
      purchaseCount: clientSales.length,
      compact: compact,
      onEdit: () => _editClient(client),
      onHistory: () => _showPurchaseHistory(client, clientSales),
      onPayment: account.remaining > 0.005 ? () => _addPayment(client, account) : null,
    );
  }

  Widget _buildHistoryPanel(DebtProvider provider) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [const Icon(Icons.history, size: 18, color: AppColors.textSecondary), const SizedBox(width: 7), const Text('Historial', style: AppTextStyles.sectionTitle), const Spacer(), Text('${provider.movements.length}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11))]),
          const SizedBox(height: 10),
          Expanded(child: provider.movements.isEmpty ? const _EmptyState(icon: Icons.receipt_long_outlined, message: 'Todavía no hay movimientos.') : ListView.separated(itemCount: provider.movements.length, separatorBuilder: (_, __) => const SizedBox(height: 7), itemBuilder: (_, index) => _MovementTile(provider.movements[index]))),
        ],
      ),
    );
  }

  List<Client> _filteredClients(List<Client> clients, DebtProvider provider, Set<String> groupedIds) {
    final query = _searchQuery.trim().toLowerCase();
    final result = clients.where((client) {
      if (groupedIds.contains(client.id)) return false;
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

  List<ClientGroup> _filteredGroups(List<ClientGroup> groups, List<Client> clients, DebtProvider provider) {
    final byId = {for (final client in clients) client.id: client};
    final query = _searchQuery.trim().toLowerCase();
    final result = groups.where((group) {
      final members = group.clientIds.map((id) => byId[id]).whereType<Client>().toList();
      if (query.isNotEmpty && !group.name.toLowerCase().contains(query) && !members.any((client) => client.name.toLowerCase().contains(query))) return false;
      final remaining = _groupRemaining(members, provider);
      if (_filter == _DebtFilter.pending && remaining <= 0.005) return false;
      if (_filter == _DebtFilter.paid && remaining > 0.005) return false;
      return true;
    }).toList();
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  double _groupTotalDebt(List<Client> clients, DebtProvider provider) => clients.fold(0, (sum, client) => sum + (provider.accountFor(client.id)?.totalDebt ?? 0));
  double _groupTotalPaid(List<Client> clients, DebtProvider provider) => clients.fold(0, (sum, client) => sum + (provider.accountFor(client.id)?.totalPaid ?? 0));
  double _groupRemaining(List<Client> clients, DebtProvider provider) => (_groupTotalDebt(clients, provider) - _groupTotalPaid(clients, provider)).clamp(0, double.infinity).toDouble();
  String _money(double value) => '\$${value.toStringAsFixed(2)}';
}

enum _DebtFilter { all, pending, paid }

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});
  @override
  Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(AppDimensions.cardRadius), border: Border.all(color: AppColors.border), boxShadow: const [BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: Offset(0, 4))]), padding: const EdgeInsets.all(14), child: child);
}

class _SummaryCard extends StatelessWidget {
  final String label; final String value; final IconData icon; final Color color;
  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(height: 82, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12), decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(AppDimensions.cardRadius), border: Border.all(color: AppColors.border), boxShadow: const [BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: Offset(0, 4))]), child: Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withAlpha(18), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 21)), const SizedBox(width: 11), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)), const SizedBox(height: 3), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary))]))]));
}

class _AmountBox extends StatelessWidget {
  final String label; final String value; final Color color;
  const _AmountBox({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7), decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary))]));
}

class _ClientDebtCard extends StatelessWidget {
  final Client client; final DebtAccount account; final int purchaseCount; final bool compact; final VoidCallback onEdit; final VoidCallback onHistory; final VoidCallback? onPayment;
  const _ClientDebtCard({required this.client, required this.account, required this.purchaseCount, required this.compact, required this.onEdit, required this.onHistory, required this.onPayment});
  @override
  Widget build(BuildContext context) {
    final remaining = account.remaining;
    final progress = account.paidPercentage;
    return Container(padding: EdgeInsets.fromLTRB(compact ? 9 : 12, compact ? 8 : 11, 10, compact ? 8 : 10), decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.border)), child: Column(children: [Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.primary.withAlpha(18), shape: BoxShape.circle), child: const Icon(Icons.person_outline, size: 19, color: AppColors.primary)), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(client.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)), if (client.phone.isNotEmpty) Text(client.phone, style: const TextStyle(fontSize: 10, color: AppColors.textMuted))])), if (purchaseCount > 0) TextButton.icon(onPressed: onHistory, icon: const Icon(Icons.receipt_long_outlined, size: 15), label: Text('$purchaseCount compras'), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 7), visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 10))), IconButton(tooltip: 'Editar', onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 17), color: AppColors.textSecondary, visualDensity: VisualDensity.compact)]), const SizedBox(height: 9), Row(children: [Expanded(child: _AmountBox(label: 'Deuda', value: _money(account.totalDebt), color: AppColors.dangerRed)), const SizedBox(width: 7), Expanded(child: _AmountBox(label: 'Abonado', value: _money(account.totalPaid), color: AppColors.successGreen)), const SizedBox(width: 7), Expanded(child: _AmountBox(label: 'Restante', value: _money(remaining), color: remaining > 0.005 ? AppColors.warningOrange : AppColors.successGreen))]), const SizedBox(height: 8), ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, minHeight: 5, backgroundColor: AppColors.border, valueColor: AlwaysStoppedAnimation<Color>(remaining > 0.005 ? AppColors.primary : AppColors.successGreen))), if (onPayment != null) Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: onPayment, icon: const Icon(Icons.payments_outlined, size: 15), label: const Text('Registrar abono'), style: TextButton.styleFrom(visualDensity: VisualDensity.compact)))]));
  }
  String _money(double value) => '\$${value.toStringAsFixed(2)}';
}

class _MovementTile extends StatelessWidget {
  final DebtMovement movement;
  const _MovementTile(this.movement);
  @override
  Widget build(BuildContext context) {
    final isPayment = movement.type == DebtMovementType.payment;
    return Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.border)), child: Row(children: [Icon(isPayment ? Icons.payments_outlined : Icons.receipt_long_outlined, size: 17, color: isPayment ? AppColors.successGreen : AppColors.dangerRed), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(movement.clientName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)), Text(isPayment ? 'Abono' : 'Fiado', style: const TextStyle(fontSize: 9, color: AppColors.textMuted))]), Text('${isPayment ? '+' : ''}\$${movement.amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isPayment ? AppColors.successGreen : AppColors.dangerRed))]));
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon; final String message;
  const _EmptyState({required this.icon, required this.message});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 30, color: AppColors.textMuted), const SizedBox(height: 8), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 11))]));
}

class _PaymentDialog extends StatefulWidget {
  final String clientName; final double debt;
  const _PaymentDialog({required this.clientName, required this.debt});
  static Future<double?> show(BuildContext context, {required String clientName, required double debt}) => showDialog<double>(context: context, builder: (_) => _PaymentDialog(clientName: clientName, debt: debt));
  @override State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _focusNode.requestFocus(); }); }
  @override void dispose() { _controller.dispose(); _focusNode.dispose(); super.dispose(); }
  void _input(String value) { _controller.text += value; _controller.selection = TextSelection.collapsed(offset: _controller.text.length); setState(() {}); }
  void _decimal() { if (_controller.text.contains('.')) return; _input('.'); }
  void _backspace() { if (_controller.text.isEmpty) return; _controller.text = _controller.text.substring(0, _controller.text.length - 1); setState(() {}); }
  void _clear() { _controller.clear(); setState(() {}); }
  void _save() { final amount = double.tryParse(_controller.text); if (amount == null || amount <= 0) return; Navigator.of(context).pop(amount); }
  @override Widget build(BuildContext context) => Dialog(child: SizedBox(width: 390, child: Padding(padding: const EdgeInsets.all(20), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text('Registrar abono', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)), const SizedBox(height: 5), Text(widget.clientName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)), const SizedBox(height: 16), Text('Deuda restante: \$${widget.debt.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)), const SizedBox(height: 10), TextField(controller: _controller, focusNode: _focusNode, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))], decoration: const InputDecoration(labelText: 'Monto recibido')), const SizedBox(height: 16), Row(children: [Expanded(child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar'))), const SizedBox(width: 8), Expanded(child: FilledButton(onPressed: _save, child: const Text('Registrar')))])])), const SizedBox(width: 12), NumericKeypad(onInput: _input, onBackspace: _backspace, onClear: _clear, onDecimal: _decimal)]))));
}
