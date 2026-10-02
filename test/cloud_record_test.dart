import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_record.dart';

void main() {
  test('keeps cloud record data at the repository boundary', () {
    const record = CloudRecord(id: 'record-1', data: <String, dynamic>{'value': 1});
    expect(record.id, 'record-1');
    expect(record.data['value'], 1);
  });
}
