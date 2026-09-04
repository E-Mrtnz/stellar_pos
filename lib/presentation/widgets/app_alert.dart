import 'dart:async';

import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';

enum AppAlertType { warning, error, success, info }

class AppAlert {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    String title = 'Aviso',
    AppAlertType type = AppAlertType.warning,
    Duration duration = const Duration(seconds: 4),
  }) {
    _timer?.cancel();
    _entry?.remove();

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned(
          top: MediaQuery.of(overlayContext).padding.top + 18,
          left: 20,
          right: 20,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: _AppAlertCard(
                message: message,
                title: title,
                type: type,
              ),
            ),
          ),
        );
      },
    );

    _entry = entry;
    overlay.insert(entry);

    _timer = Timer(duration, () {
      if (entry.mounted) entry.remove();
      if (identical(_entry, entry)) _entry = null;
    });
  }
}

class _AppAlertCard extends StatelessWidget {
  final String message;
  final String title;
  final AppAlertType type;

  const _AppAlertCard({
    required this.message,
    required this.title,
    required this.type,
  });

  Color get _backgroundColor {
    switch (type) {
      case AppAlertType.warning:
        return AppColors.warningOrange;
      case AppAlertType.error:
        return AppColors.dangerRed;
      case AppAlertType.success:
        return AppColors.successGreen;
      case AppAlertType.info:
        return AppColors.primary;
    }
  }

  IconData get _icon {
    switch (type) {
      case AppAlertType.warning:
        return Icons.warning_amber_rounded;
      case AppAlertType.error:
        return Icons.error_outline_rounded;
      case AppAlertType.success:
        return Icons.check_circle_outline_rounded;
      case AppAlertType.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
