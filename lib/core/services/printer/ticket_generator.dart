import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import 'package:stellar_pos/core/models/sale_ticket.dart';

class TicketGenerator {
  const TicketGenerator();

  Future<List<int>> generate(SaleTicketData ticket) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(
      PaperSize.mm80,
      profile,
      spaceBetweenRows: 4,
    );

    final bytes = <int>[];

    bytes.addAll(generator.reset());
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
        linesAfter: 1,
      ),
    );

    bytes.addAll(generator.hr(ch: '-'));
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

    bytes.addAll(
      generator.row([
        _left('Ticket: #${ticket.ticketNumber}', 6),
        _right('Fecha: ${ticket.date}', 6),
      ]),
    );
    bytes.addAll(
      generator.row([
        _left('Hora: ${ticket.time}', 6),
        _right('Cliente: ${ticket.client}', 6),
      ]),
    );

    bytes.addAll(generator.feed(1));
    bytes.addAll(
      generator.row([
        _center('CANT', 2),
        _left('DESCRIPCION', 5),
        _right('P.UNIT', 2),
        _right('DESC.', 1),
        _right('TOTAL', 2),
      ]),
    );
    bytes.addAll(generator.hr(ch: '-'));

    for (final item in ticket.items) {
      bytes.addAll(
        generator.row([
          _center('${item.quantity}', 2),
          _left(item.description, 5),
          _right(_money(item.unitPrice), 2),
          _right(_money(item.discount), 1),
          _right(_money(item.total), 2),
        ]),
      );
    }

    bytes.addAll(generator.hr(ch: '-'));
    bytes.addAll(_summary(generator, 'Subtotal', ticket.subtotal));
    bytes.addAll(_summary(generator, 'Descuento', ticket.discount));
    bytes.addAll(generator.hr(ch: '-'));
    bytes.addAll(
      generator.row([
        _left('TOTAL', 8, bold: true),
        _right(_money(ticket.total), 4, bold: true),
      ]),
    );

    bytes.addAll(generator.feed(1));
    bytes.addAll(
      generator.text(
        'FORMA DE PAGO: ${ticket.paymentMethod}',
        styles: const PosStyles(bold: true, codeTable: 'CP1252'),
      ),
    );
    bytes.addAll(_summary(generator, 'Recibido', ticket.received));
    bytes.addAll(_summary(generator, 'Cambio', ticket.change));

    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.hr(ch: '-'));
    bytes.addAll(
      generator.text(
        'GRACIAS POR SU COMPRA',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          codeTable: 'CP1252',
        ),
        linesAfter: 1,
      ),
    );

    bytes.addAll(generator.text(
      '#${ticket.ticketNumber}',
      styles: const PosStyles(align: PosAlign.center, codeTable: 'CP1252'),
      linesAfter: 1,
    ));

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
