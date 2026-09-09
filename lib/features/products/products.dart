/// Public entry point for the products feature.
///
/// Existing models/providers remain available from core while the application
/// is migrated incrementally. New product code should import this entry point.
export 'package:stellar_pos/core/models/product.dart';
export 'package:stellar_pos/core/providers/product_provider.dart';
export 'package:stellar_pos/core/services/domain/product_pricing_service.dart';
