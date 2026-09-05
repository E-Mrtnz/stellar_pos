import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import 'package:stellar_pos/core/models/sale_ticket.dart';

class TicketGenerator {
  const TicketGenerator();

  Future<List<int>> generate(
    SaleTicketData ticket, {
    bool openCashDrawer = false,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(
      PaperSize.mm80,
      profile,
      spaceBetweenRows: 4,
    );

    final bytes = <int>[];

    bytes.addAll(generator.reset());

    // ================================================================
    // ENCABEZADO DEL BOCETO
    // ================================================================
    // Se mantiene el encabezado como un bloque independiente: identificacion
    // del negocio, direccion y telefono, antes del comprobante.
    bytes.addAll(
      generator.text(
        'STELLAR POS',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          codeTable: 'CP1252',
        ),
      ),
    );
    bytes.addAll(
      generator.text(
        'MI TIENDA',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          codeTable: 'CP1252',
        ),
      ),
    );
    bytes.addAll(
      generator.text(
        'Direccion de la tienda',
        styles: const PosStyles(
          align: PosAlign.center,
          codeTable: 'CP1252',
        ),
      ),
    );
    bytes.addAll(
      generator.text(
        'Tel: 0000-0000',
        styles: const PosStyles(
          align: PosAlign.center,
          codeTable: 'CP1252',
        ),
      ),
    );

    bytes.addAll(generator.feed(1));
    bytes.addAll(
      generator.text(
        'COMPROBANTE DE VENTA',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          codeTable: 'CP1252',
        ),
      ),
    );
    bytes.addAll(generator.hr(ch: '-'));

    // ================================================================
    // DATOS DE LA VENTA
    // ================================================================
    bytes.addAll(
      generator.text(
        'Ticket: #${ticket.ticketNumber}',
        styles: const PosStyles(bold: true, codeTable: 'CP1252'),
      ),
    );
    bytes.addAll(
      generator.text(
        'Fecha: ${ticket.date}',
        styles: const PosStyles(codeTable: 'CP1252'),
      ),
    );
    bytes.addAll(
      generator.text(
        'Hora: ${ticket.time}',
        styles: const PosStyles(codeTable: 'CP1252'),
      ),
    );
    bytes.addAll(
      generator.text(
        'Cliente: ${ticket.client}',
        styles: const PosStyles(codeTable: 'CP1252'),
      ),
    );

    bytes.addAll(generator.feed(1));

    // ================================================================
    // DETALLE DE PRODUCTOS
    // ================================================================
    // Orden del boceto: DESCRIPCION, CANT, P.UNIT, DCTO., TOTAL.
    bytes.addAll(
      generator.row([
        _left('DESCRIPCION', 5, bold: true),
        _center('CANT', 1, bold: true),
        _right('P.UNIT', 2, bold: true),
        _right('DCTO.', 2, bold: true),
        _right('TOTAL', 2, bold: true),
      ]),
    );
    bytes.addAll(generator.hr(ch: '-'));

    for (final item in ticket.items) {
      bytes.addAll(
        generator.row([
          _left(item.description, 5),
          _center('${item.quantity}', 1),
          _right(_money(item.unitPrice), 2),
          _right(_money(item.discount), 2),
          _right(_money(item.total), 2),
        ]),
      );
    }

    bytes.addAll(generator.hr(ch: '-'));

    // ================================================================
    // TOTALES
    // ================================================================
    bytes.addAll(_summary(generator, 'Subtotal', ticket.subtotal));
    bytes.addAll(_summary(generator, 'Descuento', ticket.discount));
    bytes.addAll(
      generator.row([
        _left('TOTAL', 8, bold: true),
        _right(_money(ticket.total), 4, bold: true),
      ]),
    );

    bytes.addAll(generator.feed(1));

    // ================================================================
    // PAGO
    // ================================================================
    bytes.addAll(
      generator.text(
        'FORMA DE PAGO: ${ticket.paymentMethod}',
        styles: const PosStyles(bold: true, codeTable: 'CP1252'),
      ),
    );
    bytes.addAll(_summary(generator, 'Recibido', ticket.received));
    bytes.addAll(_summary(generator, 'Cambio', ticket.change));

    bytes.addAll(generator.feed(1));
    bytes.addAll(
      generator.text(
        'GRACIAS POR SU COMPRA',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          codeTable: 'CP1252',
        ),
      ),
    );

    bytes.addAll(generator.feed(1));

    // ================================================================
    // CODIGO DE BARRAS DEL TICKET
    // ================================================================
    final barcodeData = ticket.ticketNumber.codeUnits;
    if (barcodeData.isNotEmpty) {
      bytes.addAll(
        generator.barcode(
          Barcode.code128(barcodeData),
          width: 2,
          height: 60,
          textPos: BarcodeText.below,
          align: PosAlign.center,
        ),
      );
    }

    // La apertura de caja se solicita solamente para la impresion automatica
    // de una venta. Una reimpresion manual no vuelve a abrir la caja.
    if (openCashDrawer) {
      bytes.addAll(generator.drawer(pin: PosDrawer.pin2));
    }

    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());

    return bytes;
  }

  List<int> _summary(
    Generator generator,
    String label,
    double value,
  ) {
    return generator.row([
      _left(label, 8),
      _right(_money(value), 4),
    ]);
  }

  PosColumn _left(String text, int width, {bool bold = false}) {
    return PosColumn(
      text: text,
      width: width,
      styles: PosStyles(
        align: PosAlign.left,
        bold: bold,
        codeTable: 'CP1252',
      ),
    );
  }

  PosColumn _center(String text, int width, {bool bold = false}) {
    return PosColumn(
      text: text,
      width: width,
      styles: PosStyles(
        align: PosAlign.center,
        bold: bold,
        codeTable: 'CP1252',
      ),
    );
  }

  PosColumn _right(String text, int width, {bool bold = false}) {
    return PosColumn(
      text: text,
      width: width,
      styles: PosStyles(
        align: PosAlign.right,
        bold: bold,
        codeTable: 'CP1252',
      ),
    );
  }

  String _money(double value) => value.toStringAsFixed(2);
}
