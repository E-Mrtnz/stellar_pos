import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class ThermalPrinterService {
  Future<bool> isBluetoothEnabled() {
    return PrintBluetoothThermal.bluetoothEnabled;
  }

  Future<List<BluetoothInfo>> getPairedPrinters() {
    return PrintBluetoothThermal.pairedBluetooths;
  }

  Future<bool> connect(String macAddress) {
    return PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
  }

  Future<bool> disconnect() {
    return PrintBluetoothThermal.disconnect;
  }

  Future<bool> isConnected() {
    return PrintBluetoothThermal.connectionStatus;
  }

  Future<bool> printBytes(List<int> bytes) async {
    final connected = await isConnected();
    if (!connected) return false;
    return PrintBluetoothThermal.writeBytes(bytes);
  }
}
