class AppValidators {
  const AppValidators._();

  static String required(String? value, {String message = 'Este campo es obligatorio.'}) {
    return value == null || value.trim().isEmpty ? message : '';
  }

  static String positiveNumber(String? value, {String message = 'Ingresa un valor mayor que cero.'}) {
    final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    return parsed == null || parsed <= 0 ? message : '';
  }

  static String nonNegativeNumber(String? value, {String message = 'Ingresa un valor válido.'}) {
    final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    return parsed == null || parsed < 0 ? message : '';
  }
}
