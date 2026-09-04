import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'package:stellar_pos/core/models/sale_ticket.dart';
import 'package:stellar_pos/core/services/printer/thermal_printer_service.dart';
import 'package:stellar_pos/core/services/printer/ticket_generator.dart';

class PrinterProvider extends ChangeNotifier {
  final ThermalPrinterService _service;
  final TicketGenerator _ticketGenerator;

  PrinterProvider({
    ThermalPrinterService? service,
    TicketGenerator? ticketGenerator,
  })  : _service = service ?? ThermalPrinterService(),
        _ticketGenerator = ticketGenerator ?? const TicketGenerator();

  List<BluetoothInfo> _printers = [];
  BluetoothInfo? _selectedPrinter;
  bool _isLoading = false;
  bool _isConnected = false;
  bool _isPrinting = false;
  bool _bluetoothEnabled = false;
  String? _errorMessage;

  List<BluetoothInfo> get printers => List.unmodifiable(_printers);
  BluetoothInfo? get selectedPrinter => _selectedPrinter;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  bool get isPrinting => _isPrinting;
  bool get bluetoothEnabled => _bluetoothEnabled;
  String? get errorMessage => _errorMessage;

  Future<void> refreshPrinters() async {
    if (kIsWeb) {
      _errorMessage = 'La impresion Bluetooth no esta disponible en Web.';
      _printers = [];
      notifyListeners();
      return;
    }

    _setLoading(true);
    _errorMessage = null;

    try {
      _bluetoothEnabled = await _service.isBluetoothEnabled();
      if (!_bluetoothEnabled) {
        _printers = [];
        _errorMessage = 'Activa Bluetooth en el dispositivo.';
        return;
      }

      _printers = await _service.getPairedPrinters();
    } catch (e) {
      _errorMessage = 'No se pudieron obtener las impresoras Bluetooth.';
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> connect(BluetoothInfo printer) async {
    if (kIsWeb) {
      _errorMessage = 'La impresion Bluetooth no esta disponible en Web.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _errorMessage = null;

    try {
      final connected = await _service.connect(printer.macAdress);
      _isConnected = connected;
      if (connected) {
        _selectedPrinter = printer;
      } else {
        _errorMessage = 'No se pudo conectar con la impresora.';
      }
      return connected;
    } catch (e) {
      _isConnected = false;
      _errorMessage = 'Error al conectar con la impresora.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> disconnect() async {
    try {
      await _service.disconnect();
    } finally {
      _isConnected = false;
      notifyListeners();
    }
  }

  Future<bool> printTestTicket() async {
    if (kIsWeb) {
      _errorMessage = 'La impresion Bluetooth no esta disponible en Web.';
      notifyListeners();
      return false;
    }

    _isPrinting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final connected = await _service.isConnected();
      if (!connected) {
        _isConnected = false;
        _errorMessage = 'Conecta una impresora antes de imprimir.';
        return false;
      }

      final ticket = _buildTestTicket();
      final bytes = await _ticketGenerator.generate(ticket);
      final printed = await _service.printBytes(bytes);

      if (!printed) {
        _isConnected = false;
        _errorMessage = 'La impresora no acepto el trabajo de impresion.';
      }

      return printed;
    } catch (e) {
      _errorMessage = 'Ocurrio un error al imprimir el ticket de prueba.';
      return false;
    } finally {
      _isPrinting = false;
      notifyListeners();
    }
  }

  SaleTicketData _buildTestTicket() {
    return SaleTicketData(
      ticketNumber: '00000001',
      date: '03/09/2026',
      time: '10:21 PM',
      client: 'Consumidor final',
      items: const [
        SaleTicketItem(
          quantity: 2,
          description: 'Coca-Cola 354 ml',
          unitPrice: 1.00,
          discount: 0.00,
          total: 2.00,
        ),
        SaleTicketItem(
          quantity: 3,
          description: 'Pan frances',
          unitPrice: 0.25,
          discount: 0.05,
          total: 0.70,
        ),
        SaleTicketItem(
          quantity: 1,
          description: 'Leche entera 1 L',
          unitPrice: 1.80,
          discount: 0.00,
          total: 1.80,
        ),
      ],
      subtotal: 4.55,
      discount: 0.05,
      total: 4.50,
      paymentMethod: 'EFECTIVO',
      received: 5.00,
      change: 0.50,
    );
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
