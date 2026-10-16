import 'package:cloud_functions/cloud_functions.dart';
import 'package:stellar_pos/core/models/sale.dart';

enum CloudSaleAcceptanceStatus { applied, duplicate }

class CloudSaleAcceptance {
  const CloudSaleAcceptance({
    required this.saleId,
    required this.saleNumber,
    required this.ticketNumber,
    required this.status,
  });

  final String saleId;
  final String saleNumber;
  final String ticketNumber;
  final CloudSaleAcceptanceStatus status;

  factory CloudSaleAcceptance.fromResponse(
    Object? raw, {
    required String expectedSaleId,
  }) {
    if (raw is! Map) {
      throw const FormatException('La respuesta de aceptación de venta no es válida.');
    }
    final data = Map<String, Object?>.from(raw);
    final saleId = data['saleId'];
    final saleNumber = data['saleNumber'];
    final ticketNumber = data['ticketNumber'];
    final status = data['status'];
    if (saleId != expectedSaleId ||
        saleNumber is! String ||
        saleNumber.trim().isEmpty ||
        ticketNumber is! String ||
        (status != 'applied' && status != 'duplicate')) {
      throw const FormatException('La respuesta del servidor no coincide con la venta enviada.');
    }
    return CloudSaleAcceptance(
      saleId: saleId as String,
      saleNumber: saleNumber,
      ticketNumber: ticketNumber,
      status: status == 'applied'
          ? CloudSaleAcceptanceStatus.applied
          : CloudSaleAcceptanceStatus.duplicate,
    );
  }
}

/// Explicit transport for the server's idempotent sale-acceptance endpoint.
///
/// This is intentionally not connected to the local sale repository or worker:
/// callers must first implement recoverable local-write/outbox coordination.
class CloudSaleAcceptanceTransport {
  CloudSaleAcceptanceTransport({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<CloudSaleAcceptance> accept({
    required String storeId,
    required SaleRecord sale,
  }) async {
    if (storeId.trim().isEmpty || storeId.contains('/')) {
      throw ArgumentError.value(storeId, 'storeId', 'Identificador de tienda inválido.');
    }
    if (sale.id.trim().isEmpty || sale.id.contains('/')) {
      throw ArgumentError.value(sale.id, 'sale.id', 'Identificador de venta inválido.');
    }
    if (!sale.isCompleted) {
      throw ArgumentError('Solo se pueden enviar ventas completadas.');
    }

    final payload = Map<String, Object?>.from(sale.toMap());
    // The server assigns this field. Never trust a locally proposed sequence.
    payload['saleNumber'] = null;

    try {
      final response = await _functions.httpsCallable('acceptCloudSale').call(
        <String, Object?>{
          'storeId': storeId,
          'saleId': sale.saleId,
          'sale': payload,
        },
      );
      return CloudSaleAcceptance.fromResponse(
        response.data,
        expectedSaleId: sale.saleId,
      );
    } on FirebaseFunctionsException {
      rethrow;
    }
  }
}
