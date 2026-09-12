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
  @override State<DebtsLayout> createState() => _DebtsLayoutState();
}

class _DebtsLayoutState extends State<DebtsLayout> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _DebtFilter _filter = _DebtFilter.pending;
  final Set<String> _expandedGroups = {};

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  Future<void> _createClient() => CreateClientDialog.show(context);
  Future<void> _createGroup() => CreateClientGroupDialog.show(context);

  Future<void> _editClient(Client client) async {
    final name = TextEditingController(text: client.name);
    final phone = TextEditingController(text: client.phone);
    final address = TextEditingController(text: client.address);
    try {
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Editar cliente'),
        content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nombre')),
          const SizedBox(height: 12),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono')),
          const SizedBox(height: 12),
          TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'Dirección')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            final updated = Client(id: client.id, name: name.text, phone: phone.text, address: address.text);
            if (!context.read<CatalogProvider>().updateClient(updated)) {
              AppAlert.show(context, 'No se pudo actualizar el cliente.', title: 'Error al actualizar', type: AppAlertType.error);
              return;
            }
            context.read<DebtProvider>().renameClient(client.id, updated.name.trim());
            Navigator.pop(dialogContext);
          }, child: const Text('Guardar')),
        ],
      ));
    } finally { name.dispose(); phone.dispose(); address.dispose(); }
  }

  Future<void> _addPayment(Client client, DebtAccount account) async {
    if (account.remaining <= 0.005) return;
    final received = await _PaymentDialog.show(context, clientName: client.name, debt: account.remaining);
    if (received == null || !mounted) return;
    if (!context.read<DebtProvider>().recordPayment(clientId: client.id, clientName: client.name, amount: received)) {
      AppAlert.show(context, 'No se pudo registrar el abono.', title: 'Error al registrar', type: AppAlertType.error);
      return;
    }
    final applied = received > account.remaining ? account.remaining : received;
    final change = received > account.remaining ? received - account.remaining : 0.0;
    AppAlert.show(context, change > 0.005 ? 'Se registró un abono de ${_money(applied)}. Cambio: ${_money(change)}.' : 'Se registró un abono de ${_money(applied)}.', title: 'Abono registrado', type: AppAlertType.success);
  }

  Future<void> _history(Client client, List<SaleRecord> sales) => ClientPurchaseHistoryDialog.show(context, clientName: client.name, sales: sales);

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final debts = context.watch<DebtProvider>();
    final sales = context.watch<SalesProvider>();
    final groupsProvider = context.watch<ClientGroupProvider>();
    final groupedIds = groupsProvider.groups.expand((g) => g.clientIds).toSet();
    final clients = _filteredClients(catalog.clients, debts, groupedIds);
    final groups = _filteredGroups(groupsProvider.groups, catalog.clients, debts);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        Padding(padding: const EdgeInsets.all(AppDimensions.pagePadding), child: Column(children: [
          _summary(debts),
          const SizedBox(height: 12),
          Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: 3, child: _clientsPanel(clients, groups, debts, sales, catalog.clients)),
            const SizedBox(width: 12),
            Expanded(flex: 1, child: _historyPanel(debts)),
          ])),
        ])),
        Positioned(right: 20, bottom: 82, child: FloatingActionButton(
          heroTag: 'fab_debt_groups', tooltip: 'Crear grupo', onPressed: _createGroup,
          backgroundColor: AppColors.primary, shape: const CircleBorder(),
          child: const Icon(Icons.groups_outlined, color: Colors.white),
        )),
        Positioned(right: 20, bottom: 20, child: FloatingActionButton(
          heroTag: 'fab_debt_clients', tooltip: 'Crear cliente', onPressed: _createClient,
          backgroundColor: AppColors.primary, shape: const CircleBorder(),
          child: const Icon(Icons.person_add_alt_1_outlined, color: Colors.white),
        )),
      ]),
    );
  }

  Widget _summary(DebtProvider p) => Row(children: [
    Expanded(child: _SummaryCard('Deuda pendiente', _money(p.totalRemaining), Icons.account_balance_wallet_outlined, AppColors.dangerRed)),
    const SizedBox(width: 10),
    Expanded(child: _SummaryCard('Total abonado', _money(p.totalPaid), Icons.payments_outlined, AppColors.successGreen)),
    const SizedBox(width: 10),
    Expanded(child: _SummaryCard('Clientes con deuda', p.clientsWithDebt.toString(), Icons.people_outline, AppColors.primary)),
  ]);

  Widget _clientsPanel(List<Client> clients, List<ClientGroup> groups, DebtProvider debts, SalesProvider sales, List<Client> allClients) => _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [const Text('Clientes', style: AppTextStyles.sectionTitle), const Spacer(), Text('${clients.length + groups.length}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11))]),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: ProductSearchBar(controller: _searchController, hintText: 'Buscar cliente o grupo...', onChanged: (v) => setState(() => _searchQuery = v))),
      const SizedBox(width: 10),
      DropdownButtonHideUnderline(child: DropdownButton<_DebtFilter>(value: _filter, items: const [
        DropdownMenuItem(value: _DebtFilter.all, child: Text('Todos')),
        DropdownMenuItem(value: _DebtFilter.pending, child: Text('Con deuda')),
        DropdownMenuItem(value: _DebtFilter.paid, child: Text('Pagados')),
      ], onChanged: (v) { if (v != null) setState(() => _filter = v); })),
    ]),
    const SizedBox(height: 10),
    Expanded(child: clients.isEmpty && groups.isEmpty
      ? const _EmptyState('No hay clientes o grupos que coincidan con el filtro.', Icons.people_outline)
      : ListView.separated(
          padding: const EdgeInsets.only(bottom: 80), itemCount: groups.length + clients.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => i < groups.length ? _groupCard(groups[i], allClients, debts, sales) : _clientCard(clients[i - groups.length], debts, sales),
        )),
  ]));

  Widget _groupCard(ClientGroup group, List<Client> allClients, DebtProvider debts, SalesProvider sales) {
    final members = allClients.where((c) => group.clientIds.contains(c.id)).toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final debt = members.fold<double>(0, (s, c) => s + (debts.accountFor(c.id)?.totalDebt ?? 0));
    final paid = members.fold<double>(0, (s, c) => s + (debts.accountFor(c.id)?.totalPaid ?? 0));
    final remaining = (debt - paid).clamp(0, double.infinity).toDouble();
    final expanded = _expandedGroups.contains(group.id);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(8),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.primary.withAlpha(75), width: 1.2),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => expanded ? _expandedGroups.remove(group.id) : _expandedGroups.add(group.id)),
          borderRadius: BorderRadius.circular(13),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(12),
              borderRadius: expanded ? const BorderRadius.vertical(top: Radius.circular(13)) : BorderRadius.circular(13),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Row(children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.primary.withAlpha(28), shape: BoxShape.circle), child: const Icon(Icons.groups_rounded, color: AppColors.primary, size: 20)),
                const SizedBox(width: 9),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(group.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                    const SizedBox(width: 7),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.primary.withAlpha(28), borderRadius: BorderRadius.circular(5)), child: const Text('GRUPO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: .4, color: AppColors.primary))),
                  ]),
                  const SizedBox(height: 2),
                  Text('${members.length} integrantes', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                ])),
                Text(_money(remaining), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: remaining > .005 ? AppColors.dangerRed : AppColors.successGreen)),
                const SizedBox(width: 5),
                Icon(expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.primary),
              ]),
              const SizedBox(height: 9),
              Row(children: [Expanded(child: _AmountBox('Deuda', _money(debt), AppColors.dangerRed)), const SizedBox(width: 7), Expanded(child: _AmountBox('Abonado', _money(paid), AppColors.successGreen)), const SizedBox(width: 7), Expanded(child: _AmountBox('Restante', _money(remaining), remaining > .005 ? AppColors.warningOrange : AppColors.successGreen))]),
            ]),
          ),
        ),
        if (expanded)
          Container(
            decoration: const BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.vertical(bottom: Radius.circular(13))),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(padding: const EdgeInsets.fromLTRB(5, 0, 5, 4), child: Row(children: [const Icon(Icons.people_outline, size: 14, color: AppColors.primary), const SizedBox(width: 5), const Text('INTEGRANTES DEL GRUPO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .45, color: AppColors.primary)), const Spacer(), Text('${members.length}', style: const TextStyle(fontSize: 9, color: AppColors.textMuted))])),
              const Divider(height: 8, color: AppColors.border),
              ...members.map((c) => Padding(padding: const EdgeInsets.only(bottom: 7), child: _clientCard(c, debts, sales, compact: true))),
              if (members.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Center(child: Text('Este grupo no tiene clientes asignados.', style: TextStyle(color: AppColors.textMuted, fontSize: 11)))),
            ]),
          ),
      ]),
    );
  }

  Widget _clientCard(Client client, DebtProvider debts, SalesProvider sales, {bool compact = false}) {
    final account = debts.accountFor(client.id) ?? DebtAccount(clientId: client.id, clientName: client.name, totalDebt: 0, totalPaid: 0);
    final purchases = sales.sales.where((s) => s.clientId == client.id && s.paymentMethod.toLowerCase() == 'fiado').toList(growable: false);
    return _ClientCard(client: client, account: account, purchaseCount: purchases.length, compact: compact, onEdit: () => _editClient(client), onHistory: () => _history(client, purchases), onPayment: account.remaining > .005 ? () => _addPayment(client, account) : null);
  }

  Widget _historyPanel(DebtProvider p) => _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [const Icon(Icons.history, size: 18, color: AppColors.textSecondary), const SizedBox(width: 7), const Text('Historial', style: AppTextStyles.sectionTitle), const Spacer(), Text('${p.movements.length}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11))]),
    const SizedBox(height: 10),
    Expanded(child: p.movements.isEmpty ? const _EmptyState('Todavía no hay movimientos.', Icons.receipt_long_outlined) : ListView.separated(itemCount: p.movements.length, separatorBuilder: (_, __) => const SizedBox(height: 7), itemBuilder: (_, i) => _MovementTile(p.movements[i]))),
  ]));

  List<Client> _filteredClients(List<Client> source, DebtProvider p, Set<String> grouped) {
    final q = _searchQuery.trim().toLowerCase();
    return source.where((c) {
      if (grouped.contains(c.id)) return false;
      if (q.isNotEmpty && !c.name.toLowerCase().contains(q) && !c.phone.toLowerCase().contains(q)) return false;
      final remaining = p.accountFor(c.id)?.remaining ?? 0;
      if (_filter == _DebtFilter.pending && remaining <= .005) return false;
      if (_filter == _DebtFilter.paid && remaining > .005) return false;
      return true;
    }).toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  List<ClientGroup> _filteredGroups(List<ClientGroup> source, List<Client> clients, DebtProvider p) {
    final byId = {for (final c in clients) c.id: c};
    final q = _searchQuery.trim().toLowerCase();
    return source.where((g) {
      final members = g.clientIds.map((id) => byId[id]).whereType<Client>().toList();
      final remaining = members.fold<double>(0, (s, c) => s + (p.accountFor(c.id)?.remaining ?? 0));
      if (q.isNotEmpty && !g.name.toLowerCase().contains(q) && !members.any((c) => c.name.toLowerCase().contains(q))) return false;
      if (_filter == _DebtFilter.pending && remaining <= .005) return false;
      if (_filter == _DebtFilter.paid && remaining > .005) return false;
      return true;
    }).toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  String _money(double value) => '\$${value.toStringAsFixed(2)}';
}

enum _DebtFilter { all, pending, paid }

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(AppDimensions.cardRadius), border: Border.all(color: AppColors.border), boxShadow: const [BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: Offset(0, 4))]), child: child);
}

class _SummaryCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _SummaryCard(this.label, this.value, this.icon, this.color);
  @override Widget build(BuildContext context) => Container(height: 82, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(AppDimensions.cardRadius), border: Border.all(color: AppColors.border)), child: Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withAlpha(18), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color)), const SizedBox(width: 10), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)), const SizedBox(height: 3), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary))]))]));
}

class _AmountBox extends StatelessWidget {
  final String label, value; final Color color;
  const _AmountBox(this.label, this.value, this.color);
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7), decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary))]));
}

class _ClientCard extends StatelessWidget {
  final Client client; final DebtAccount account; final int purchaseCount; final bool compact; final VoidCallback onEdit, onHistory; final VoidCallback? onPayment;
  const _ClientCard({required this.client, required this.account, required this.purchaseCount, required this.compact, required this.onEdit, required this.onHistory, required this.onPayment});
  @override Widget build(BuildContext context) => Container(padding: EdgeInsets.fromLTRB(compact ? 9 : 12, compact ? 8 : 11, 10, compact ? 8 : 10), decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.border)), child: Column(children: [Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.primary.withAlpha(18), shape: BoxShape.circle), child: const Icon(Icons.person_outline, size: 19, color: AppColors.primary)), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(client.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)), if (client.phone.isNotEmpty) Text(client.phone, style: const TextStyle(fontSize: 10, color: AppColors.textMuted))])), if (purchaseCount > 0) TextButton.icon(onPressed: onHistory, icon: const Icon(Icons.receipt_long_outlined, size: 15), label: Text('$purchaseCount compras'), style: TextButton.styleFrom(visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 10))), IconButton(tooltip: 'Editar', onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 17), color: AppColors.textSecondary, visualDensity: VisualDensity.compact)]), const SizedBox(height: 9), Row(children: [Expanded(child: _AmountBox('Deuda', '\$${account.totalDebt.toStringAsFixed(2)}', AppColors.dangerRed)), const SizedBox(width: 7), Expanded(child: _AmountBox('Abonado', '\$${account.totalPaid.toStringAsFixed(2)}', AppColors.successGreen)), const SizedBox(width: 7), Expanded(child: _AmountBox('Restante', '\$${account.remaining.toStringAsFixed(2)}', account.remaining > .005 ? AppColors.warningOrange : AppColors.successGreen))]), if (onPayment != null) Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: onPayment, icon: const Icon(Icons.payments_outlined, size: 15), label: const Text('Registrar abono'), style: TextButton.styleFrom(visualDensity: VisualDensity.compact)))]));
}

class _MovementTile extends StatelessWidget {
  final DebtMovement movement;
  const _MovementTile(this.movement);
  @override Widget build(BuildContext context) { final isPayment = movement.type == DebtMovementType.payment; return Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.border)), child: Row(children: [Icon(isPayment ? Icons.payments_outlined : Icons.receipt_long_outlined, size: 17, color: isPayment ? AppColors.successGreen : AppColors.dangerRed), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(movement.clientName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)), Text(isPayment ? 'Abono' : 'Fiado', style: const TextStyle(fontSize: 9, color: AppColors.textMuted))])), Text('${isPayment ? '+' : ''}\$${movement.amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isPayment ? AppColors.successGreen : AppColors.dangerRed))])); }
}

class _EmptyState extends StatelessWidget {
  final String message; final IconData icon;
  const _EmptyState(this.message, this.icon);
  @override Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 30, color: AppColors.textMuted), const SizedBox(height: 8), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 11))]));
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
  void _backspace() { if (_controller.text.isEmpty) return; _controller.text = _controller.text.substring(0, _controller.text.length - 1); setState(() {}); }
  void _clear() { _controller.clear(); setState(() {}); }
  void _decimal() { if (!_controller.text.contains('.')) _input('.'); }
  void _save() { final amount = double.tryParse(_controller.text); if (amount == null || amount <= 0) return; Navigator.pop(context, amount); }
  @override Widget build(BuildContext context) => Dialog(child: SizedBox(width: 390, child: Padding(padding: const EdgeInsets.all(20), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text('Registrar abono', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)), const SizedBox(height: 5), Text(widget.clientName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)), const SizedBox(height: 16), Text('Deuda restante: \$${widget.debt.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)), const SizedBox(height: 10), TextField(controller: _controller, focusNode: _focusNode, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))], decoration: const InputDecoration(labelText: 'Monto recibido')), const SizedBox(height: 16), Row(children: [Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar'))), const SizedBox(width: 8), Expanded(child: FilledButton(onPressed: _save, child: const Text('Registrar')))])])), const SizedBox(width: 12), NumericKeypad(onInput: _input, onBackspace: _backspace, onClear: _clear, onDecimal: _decimal)]))));
}
