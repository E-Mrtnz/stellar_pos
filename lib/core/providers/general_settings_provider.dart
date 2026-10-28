import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeneralSettingsProvider extends ChangeNotifier {
  static const _showImportKey = 'general.show_inventory_import';
  static const _showExportKey = 'general.show_inventory_export';
  static const _barcodeSuccessSoundKey = 'general.sound.barcode_success';
  static const _barcodeErrorSoundKey = 'general.sound.barcode_error';
  static const _saleSuccessSoundKey = 'general.sound.sale_success';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  bool _showInventoryImport = true;
  bool _showInventoryExport = true;
  bool _barcodeSuccessSound = true;
  bool _barcodeErrorSound = true;
  bool _saleSuccessSound = true;

  bool get showInventoryImport => _showInventoryImport;
  bool get showInventoryExport => _showInventoryExport;
  bool get barcodeSuccessSound => _barcodeSuccessSound;
  bool get barcodeErrorSound => _barcodeErrorSound;
  bool get saleSuccessSound => _saleSuccessSound;

  GeneralSettingsProvider() {
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final importValue = await _preferences.getBool(_showImportKey);
      final exportValue = await _preferences.getBool(_showExportKey);
      final barcodeSuccess = await _preferences.getBool(_barcodeSuccessSoundKey);
      final barcodeError = await _preferences.getBool(_barcodeErrorSoundKey);
      final saleSuccess = await _preferences.getBool(_saleSuccessSoundKey);
      if (importValue != null) _showInventoryImport = importValue;
      if (exportValue != null) _showInventoryExport = exportValue;
      if (barcodeSuccess != null) _barcodeSuccessSound = barcodeSuccess;
      if (barcodeError != null) _barcodeErrorSound = barcodeError;
      if (saleSuccess != null) _saleSuccessSound = saleSuccess;
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

  void setBarcodeSuccessSound(bool value) {
    _barcodeSuccessSound = value;
    notifyListeners();
    unawaited(_preferences.setBool(_barcodeSuccessSoundKey, value));
  }

  void setBarcodeErrorSound(bool value) {
    _barcodeErrorSound = value;
    notifyListeners();
    unawaited(_preferences.setBool(_barcodeErrorSoundKey, value));
  }

  void setSaleSuccessSound(bool value) {
    _saleSuccessSound = value;
    notifyListeners();
    unawaited(_preferences.setBool(_saleSuccessSoundKey, value));
  }
}
