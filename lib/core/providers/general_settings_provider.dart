import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeneralSettingsProvider extends ChangeNotifier {
  static const _showImportKey = 'general.show_inventory_import';
  static const _showExportKey = 'general.show_inventory_export';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  bool _showInventoryImport = true;
  bool _showInventoryExport = true;

  bool get showInventoryImport => _showInventoryImport;
  bool get showInventoryExport => _showInventoryExport;

  GeneralSettingsProvider() {
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final importValue = await _preferences.getBool(_showImportKey);
      final exportValue = await _preferences.getBool(_showExportKey);
      if (importValue != null) _showInventoryImport = importValue;
      if (exportValue != null) _showInventoryExport = exportValue;
      notifyListeners();
    } catch (_) {
      // Keep safe defaults when preferences cannot be read.
    }
  }

  void setShowInventoryImport(bool value) {
    _showInventoryImport = value;
    notifyListeners();
    unawaited(_preferences.setBool(_showImportKey, value));
  }

  void setShowInventoryExport(bool value) {
    _showInventoryExport = value;
    notifyListeners();
    unawaited(_preferences.setBool(_showExportKey, value));
  }
}
