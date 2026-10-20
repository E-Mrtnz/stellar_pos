import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:stellar_pos/core/constants/app_constants.dart';

class CompactCameraBarcodeScanner extends StatefulWidget {
  final String? Function(String barcode) onBarcodeDetected;
  final VoidCallback onClose;
  const CompactCameraBarcodeScanner({super.key, required this.onBarcodeDetected, required this.onClose});
  @override
  State<CompactCameraBarcodeScanner> createState() => _CompactCameraBarcodeScannerState();
}

class _CompactCameraBarcodeScannerState extends State<CompactCameraBarcodeScanner> {
  late final MobileScannerController _controller;
  final AudioPlayer _feedbackPlayer = AudioPlayer();
  Timer? _releaseTimer;
  String? _lastBarcode;
  String _status = 'Apunta al código de barras del producto';
  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(detectionSpeed: DetectionSpeed.normal);
  }
  @override
  void dispose() {
    _releaseTimer?.cancel();
    unawaited(_controller.dispose());
    unawaited(_feedbackPlayer.dispose());
    super.dispose();
  }
  Future<void> _playFeedback(String asset) async {
    try {
      await _feedbackPlayer.stop();
      await _feedbackPlayer.play(AssetSource(asset));
    } catch (_) {
      // Audio feedback must never interrupt barcode scanning.
    }
  }

  void _detect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty || value == _lastBarcode) continue;
      _lastBarcode = value;
      _releaseTimer?.cancel();
      _releaseTimer = Timer(const Duration(milliseconds: 900), () => _lastBarcode = null);
      final productId = widget.onBarcodeDetected(value);
      if (!mounted) return;
      setState(() => _status = productId == null ? 'No se encontró el código: $value' : 'Producto agregado correctamente');
      unawaited(productId == null ? HapticFeedback.heavyImpact() : HapticFeedback.selectionClick());
      unawaited(_playFeedback(productId == null ? 'audio/barcode_error.mp3' : 'audio/barcode_success.mp3'));
      return;
    }
  }
  @override
  Widget build(BuildContext context) => Material(
    elevation: 16,
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      width: 310,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
          child: Row(children: [
            const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('Escáner de productos', style: TextStyle(fontWeight: FontWeight.w800))),
            IconButton(tooltip: 'Linterna', visualDensity: VisualDensity.compact, onPressed: _controller.toggleTorch, icon: const Icon(Icons.flashlight_on_outlined)),
            IconButton(tooltip: 'Cerrar escáner', visualDensity: VisualDensity.compact, onPressed: widget.onClose, icon: const Icon(Icons.close_rounded)),
          ]),
        ),
        SizedBox(height: 190, width: double.infinity, child: MobileScanner(controller: _controller, onDetect: _detect, fit: BoxFit.cover)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, size: 17, color: AppColors.textSecondary),
            const SizedBox(width: 7),
            Expanded(child: Text(_status, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          ]),
        ),
      ]),
    ),
  );
}
