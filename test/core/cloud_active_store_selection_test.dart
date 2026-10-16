import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stellar_pos/core/cloud_active_store_selection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('persists a selected store scoped to the signed-in user', () async {
    const selection = SharedPreferencesActiveCloudStoreSelection();

    expect(await selection.read('user-a'), isNull);
    await selection.write('user-a', 'store-a');
    await selection.write('user-b', 'store-b');

    expect(await selection.read('user-a'), 'store-a');
    expect(await selection.read('user-b'), 'store-b');
  });

  test('clears a selection without affecting another user', () async {
    const selection = SharedPreferencesActiveCloudStoreSelection();
    await selection.write('user-a', 'store-a');
    await selection.write('user-b', 'store-b');

    await selection.clear('user-a');

    expect(await selection.read('user-a'), isNull);
    expect(await selection.read('user-b'), 'store-b');
  });

  test('rejects invalid identifiers and ignores malformed saved values', () async {
    const selection = SharedPreferencesActiveCloudStoreSelection();

    await expectLater(selection.write('user-a', 'bad/store'), throwsArgumentError);
    await expectLater(selection.read('bad/user'), throwsArgumentError);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cloud_active_store_v1_user-a', 'bad/store');
    expect(await selection.read('user-a'), isNull);
  });
}
