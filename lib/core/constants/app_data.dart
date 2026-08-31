import 'package:stellar_pos/core/constants/app_constants.dart';

class AppData {
  const AppData._();

  static const List<Map<String, dynamic>> paymentMethods = [
    {
      'index': AppPaymentMethods.cash,
      'icon': 'cash',
      'label': AppStrings.cashPayment,
    },
    {
      'index': AppPaymentMethods.card,
      'icon': 'card',
      'label': AppStrings.cardPayment,
    },
    {
      'index': AppPaymentMethods.transfer,
      'icon': 'transfer',
      'label': AppStrings.transferPayment,
    },
    {
      'index': AppPaymentMethods.credit,
      'icon': 'credit',
      'label': AppStrings.creditPayment,
    },
  ];
}
