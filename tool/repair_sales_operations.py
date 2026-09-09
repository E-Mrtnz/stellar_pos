from pathlib import Path
import re


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    if old not in text:
        raise SystemExit(f'Expected text was not found in {path}: {old!r}')
    path.write_text(text.replace(old, new, 1))


dialog = Path('lib/presentation/dashboard/widgets/sale_detail_dialog.dart')
replace_once(
    dialog,
    "]); });\n  ]));",
    "])); })\n  ]));",
)

dialog_text = dialog.read_text()
marker = "  void _submit() { final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;"
if "String _money(double value) =>" not in dialog_text and marker in dialog_text:
    dialog_text = dialog_text.replace(
        marker,
        "  String _money(double value) => '\\$${value.toStringAsFixed(2)}';\n  " + marker,
        1,
    )
    dialog.write_text(dialog_text)

sales_layout = Path('lib/presentation/sales/sales_layout.dart')
sales_text = sales_layout.read_text()
pattern = re.compile(
    r"  Widget _saleRow\(SaleRecord sale, double paid\) \{.*?\n  Widget _statusOperationBadges",
    re.S,
)
replacement = r'''  Widget _saleRow(SaleRecord sale, double paid) {
    final credit = sale.paymentMethod == AppStrings.creditPayment;
    final pending = credit
        ? (sale.effectiveTotal - paid).clamp(0, double.infinity).toDouble()
        : 0.0;
    final items = _effectiveItemCount(sale);
    final time =
        '${sale.createdAt.hour.toString().padLeft(2, '0')}:${sale.createdAt.minute.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: () => _showDetails(sale, paid),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 78,
              child: Text(
                '#${sale.ticketNumber}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            SizedBox(
              width: 105,
              child: Text(
                '${_date(sale.createdAt)}\n$time',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                sale.clientName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '$items artículo${items == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            SizedBox(width: 100, child: _paymentBadge(sale.paymentMethod)),
            SizedBox(width: 185, child: _statusOperationBadges(sale)),
            SizedBox(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _money(sale.effectiveTotal),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (credit)
                    Text(
                      pending <= .005
                          ? 'Pagada'
                          : 'Pendiente ${_money(pending)}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: pending <= .005
                            ? AppColors.successGreen
                            : AppColors.dangerRed,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusOperationBadges'''

sales_text, count = pattern.subn(lambda _: replacement, sales_text, count=1)
if count != 1:
    raise SystemExit('Expected _saleRow method was not found.')
sales_layout.write_text(sales_text)

for raw_path in (
    'lib/presentation/dashboard/main_dashboard_layout.dart',
    'lib/presentation/debts/client_purchase_history_dialog.dart',
):
    path = Path(raw_path)
    text = path.read_text()
    if 'deleteSale(' in text:
        path.write_text(text.replace('deleteSale(', 'annulSale(', 1))

trigger = Path('lib/presentation/widgets/app_alert.dart')
trigger.write_text(trigger.read_text().replace('// TEMP_SALES_REPAIR_TRIGGER\n', ''))
