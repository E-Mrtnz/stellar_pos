import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_sale_acceptance_transport.dart';

void main() {
  group('CloudSaleAcceptance.fromResponse', () {
    test('parses a newly accepted sale', () {
      final result = CloudSaleAcceptance.fromResponse(
        <String, Object?>{
          'saleId': 'sale-1',
          'saleNumber': '42',
          'ticketNumber': '42',
          'status': 'applied',
        },
        expectedSaleId: 'sale-1',
      );

      expect(result.saleId, 'sale-1');
      expect(result.saleNumber, '42');
      expect(result.ticketNumber, '42');
      expect(result.status, CloudSaleAcceptanceStatus.applied);
    });

    test('parses an idempotent duplicate with the original number', () {
      final result = CloudSaleAcceptance.fromResponse(
        <String, Object?>{
          'saleId': 'sale-1',
          'saleNumber': '42',
          'ticketNumber': 'local-ticket',
          'status': 'duplicate',
        },
        expectedSaleId: 'sale-1',
      );

      expect(result.status, CloudSaleAcceptanceStatus.duplicate);
      expect(result.saleNumber, '42');
    });

    test('rejects a response for another sale or missing sequence', () {
      expect(
        () => CloudSaleAcceptance.fromResponse(
          <String, Object?>{
            'saleId': 'sale-2',
            'saleNumber': '42',
            'ticketNumber': '42',
            'status': 'applied',
          },
          expectedSaleId: 'sale-1',
        ),
        throwsFormatException,
      );
      expect(
        () => CloudSaleAcceptance.fromResponse(
          <String, Object?>{
            'saleId': 'sale-1',
            'ticketNumber': '42',
            'status': 'applied',
          },
          expectedSaleId: 'sale-1',
        ),
        throwsFormatException,
      );
    });
  });
}
