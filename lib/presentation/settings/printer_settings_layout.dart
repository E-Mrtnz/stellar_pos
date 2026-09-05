import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/providers/printer_provider.dart';
import 'package:stellar_pos/presentation/widgets/app_alert.dart';

class PrinterSettingsLayout extends StatefulWidget {
  const PrinterSettingsLayout({super.key});

  @override
  State<PrinterSettingsLayout> createState() => _PrinterSettingsLayoutState();
}

class _PrinterSettingsLayoutState extends State<PrinterSettingsLayout> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PrinterProvider>().refreshPrinters();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const _WebUnavailablePanel();
    }

    return Consumer<PrinterProvider>(
      builder: (context, printer, _) {
        return Padding(
          padding: const EdgeInsets.all(AppDimensions.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ajustes', style: AppTextStyles.brandTitle),
              const SizedBox(height: 4),
              const Text(
                'Configuracion de impresion',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildPrinterCard(context, printer),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrinterCard(BuildContext context, PrinterProvider printer) {
    final selected = printer.selectedPrinter;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.largeCardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.print_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Impresora de tickets',
                      style: AppTextStyles.sectionTitle,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Bluetooth · Papel 80 mm',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _ConnectionBadge(connected: printer.isConnected),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          if (selected != null) ...[
            Text(
              'Impresora seleccionada',
              style: AppTextStyles.ticketLabel.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              selected.name.isEmpty ? 'Impresora Bluetooth' : selected.name,
              style: AppTextStyles.ticketValue,
            ),
            const SizedBox(height: 2),
            Text(
              selected.macAdress,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.print_rounded,
                  size: 19,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Imprimir al crear una venta',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Imprime automáticamente el ticket al completar la venta.',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: printer.printAutomaticallyOnSale,
                  onChanged: printer.setPrintAutomaticallyOnSale,
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: printer.isLoading ? null : printer.refreshPrinters,
                  icon: printer.isLoading
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 17),
                  label: const Text('Buscar impresoras'),
                ),
              ),
              if (printer.isConnected) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: printer.disconnect,
                  icon: const Icon(Icons.link_off, size: 17),
                  label: const Text('Desconectar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.dangerRed,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (printer.printers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                printer.errorMessage ??
                    'No hay impresoras emparejadas. Primero vincula la impresora desde Bluetooth del dispositivo.',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            Column(
              children: printer.printers
                  .map((device) => _buildPrinterTile(context, printer, device))
                  .toList(),
            ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'La prueba imprime un comprobante de ejemplo con la misma plantilla utilizada por las ventas reales. No crea ni modifica ventas.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textDarkSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: printer.isConnected && !printer.isPrinting
                  ? () => _printTest(context, printer)
                  : null,
              icon: printer.isPrinting
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.receipt_long_outlined, size: 18),
              label: Text(
                printer.isPrinting ? 'Imprimiendo...' : 'Imprimir ticket de prueba',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
                ),
              ),
            ),
          ),
          if (printer.errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              printer.errorMessage!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.dangerRed,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrinterTile(
    BuildContext context,
    PrinterProvider printer,
    BluetoothInfo device,
  ) {
    final isSelected = printer.selectedPrinter?.macAdress == device.macAdress;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withAlpha(12)
            : AppColors.inputBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
        ),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          Icons.print_outlined,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
        ),
        title: Text(
          device.name.isEmpty ? 'Impresora Bluetooth' : device.name,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          device.macAdress,
          style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
        ),
        trailing: SizedBox(
          height: 30,
          child: ElevatedButton(
            onPressed: printer.isLoading
                ? null
                : () async {
                    final connected = await printer.connect(device);
                    if (!context.mounted) return;
                    AppAlert.show(
                      context,
                      connected
                          ? 'Impresora conectada correctamente.'
                          : printer.errorMessage ?? 'No se pudo conectar.',
                      title: connected ? 'Conexión completada' : 'No se pudo conectar',
                      type: connected
                          ? AppAlertType.success
                          : AppAlertType.error,
                    );
                  },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              elevation: 0,
              backgroundColor: isSelected
                  ? AppColors.successGreen
                  : AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              isSelected ? 'Seleccionada' : 'Conectar',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _printTest(
    BuildContext context,
    PrinterProvider printer,
  ) async {
    final result = await printer.printTestTicket();
    if (!context.mounted) return;

    AppAlert.show(
      context,
      result
          ? 'Ticket de prueba enviado a la impresora.'
          : printer.errorMessage ?? 'No se pudo imprimir el ticket.',
      title: result ? 'Impresión completada' : 'No se pudo imprimir',
      type: result ? AppAlertType.success : AppAlertType.error,
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  final bool connected;

  const _ConnectionBadge({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: connected
            ? AppColors.successGreen.withAlpha(18)
            : AppColors.inputBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: connected ? AppColors.successGreen : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 7,
            color: connected
                ? AppColors.successGreen
                : AppColors.textMuted,
          ),
          const SizedBox(width: 5),
          Text(
            connected ? 'Conectada' : 'Desconectada',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: connected
                  ? AppColors.successGreen
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WebUnavailablePanel extends StatelessWidget {
  const _WebUnavailablePanel();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'La impresion Bluetooth no esta disponible desde la version Web de Stellar POS. Usa Android, iOS, macOS o Windows para conectar una impresora Bluetooth.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
