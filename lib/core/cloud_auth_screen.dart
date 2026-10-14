import 'package:flutter/material.dart';

import 'cloud_auth_gateway.dart';

/// Explicit cloud sign-in screen.
///
/// This screen is intentionally not the application's home route: local POS
/// workflows remain available without an account or network. Navigate here
/// only when the user chooses a cloud account action.
class CloudAuthScreen extends StatefulWidget {
  const CloudAuthScreen({
    required this.gateway,
    super.key,
    this.onAuthenticated,
    this.embedded = false,
  });

  final CloudAuthGateway gateway;
  final ValueChanged<CloudAuthUser>? onAuthenticated;
  final bool embedded;

  @override
  State<CloudAuthScreen> createState() => _CloudAuthScreenState();
}

class _CloudAuthScreenState extends State<CloudAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegistering = false;
  bool _isBusy = false;
  bool _obscurePassword = true;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty || !email.contains('@') || email.endsWith('@')) {
      return 'Introduce un correo válido.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Introduce tu contraseña.';
    if (_isRegistering && password.length < 6) {
      return 'Usa al menos 6 caracteres.';
    }
    return null;
  }

  String _friendlyError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('email-already-in-use')) {
      return 'Ese correo ya tiene una cuenta.';
    }
    if (text.contains('invalid-email')) return 'El correo no es válido.';
    if (text.contains('weak-password')) {
      return 'La contraseña es demasiado débil.';
    }
    if (text.contains('user-not-found') ||
        text.contains('wrong-password') ||
        text.contains('invalid-credential')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (text.contains('network-request-failed') ||
        text.contains('unavailable')) {
      return 'No hay conexión con el servicio. Puedes seguir usando la caja local.';
    }
    if (text.contains('invalid-phone-number')) {
      return 'El número no es válido. Incluye el código de país, por ejemplo +503.';
    }
    if (text.contains('invalid-verification-code') ||
        text.contains('session-expired') ||
        text.contains('code-expired')) {
      return 'El código SMS no es válido o ya venció. Solicita uno nuevo.';
    }
    if (text.contains('quota-exceeded')) {
      return 'Se alcanzó el límite de SMS. Inténtalo más tarde.';
    }
    if (text.contains('sign-in-cancelled') || text.contains('canceled')) {
      return 'Se canceló el inicio de sesión.';
    }
    if (text.contains('too-many-requests')) {
      return 'Demasiados intentos. Espera un momento y vuelve a intentarlo.';
    }
    return 'No se pudo completar la operación. Verifica la configuración de Firebase e inténtalo de nuevo.';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isBusy = true;
      _message = null;
    });

    try {
      final user = _isRegistering
          ? await widget.gateway.createAccount(
              email: _emailController.text,
              password: _passwordController.text,
            )
          : await widget.gateway.signIn(
              email: _emailController.text,
              password: _passwordController.text,
            );
      if (!mounted) return;
      setState(() {
        _isError = false;
        _message = 'Sesión iniciada como ${user.email ?? user.uid}.';
      });
      widget.onAuthenticated?.call(user);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _message = _friendlyError(error);
      });
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();
    final validation = _validateEmail(_emailController.text);
    if (validation != null) {
      setState(() {
        _isError = true;
        _message = validation;
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _message = null;
    });
    try {
      await widget.gateway.sendPasswordResetEmail(
        email: _emailController.text,
      );
      if (!mounted) return;
      setState(() {
        _isError = false;
        _message = 'Si la cuenta existe, recibirás instrucciones por correo.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _message = _friendlyError(error);
      });
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _isRegistering = !_isRegistering;
      _message = null;
    });
  }

  Future<void> _signInWithProvider({
    required Future<CloudAuthUser> Function() authenticate,
  }) async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _message = null;
    });
    try {
      final user = await authenticate();
      if (!mounted) return;
      setState(() {
        _isError = false;
        _message = 'Sesión iniciada como ${user.email ?? user.uid}.';
      });
      widget.onAuthenticated?.call(user);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _message = error is UnsupportedError
            ? error.message?.toString() ?? 'Este método no está disponible en esta plataforma.'
            : _friendlyError(error);
      });
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _phoneSignInFlow() async {
    if (_isBusy) return;
    final phoneController = TextEditingController();
    final codeController = TextEditingController();
    var codeSent = false;
    var sending = false;
    String? dialogError;
    setState(() {
      _isBusy = true;
      _message = null;
    });

    try {
      final user = await showDialog<CloudAuthUser>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Acceder con teléfono'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    codeSent
                        ? 'Introduce el código SMS que recibiste.'
                        : 'Escribe tu número con código de país. Ejemplo: +503XXXXXXXX.',
                  ),
                  const SizedBox(height: 16),
                  if (!codeSent)
                    TextField(
                      key: const ValueKey('cloud-auth-phone-number'),
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Número de teléfono',
                        hintText: '+503XXXXXXXX',
                      ),
                    )
                  else
                    TextField(
                      key: const ValueKey('cloud-auth-phone-code'),
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Código SMS',
                      ),
                    ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      dialogError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: sending ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: sending
                    ? null
                    : () async {
                        setDialogState(() {
                          sending = true;
                          dialogError = null;
                        });
                        try {
                          if (!codeSent) {
                            await widget.gateway.sendPhoneVerificationCode(
                              phoneNumber: phoneController.text,
                            );
                            setDialogState(() {
                              codeSent = true;
                              sending = false;
                            });
                          } else {
                            final user = await widget.gateway.verifyPhoneCode(
                              smsCode: codeController.text,
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(user);
                            }
                          }
                        } catch (error) {
                          setDialogState(() {
                            sending = false;
                            dialogError = error is UnsupportedError
                                ? error.message?.toString() ?? 'Este método no está disponible.'
                                : _friendlyError(error);
                          });
                        }
                      },
                child: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(codeSent ? 'Verificar código' : 'Enviar código'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || user == null) return;
      setState(() {
        _isError = false;
        _message = 'Sesión iniciada como ${user.email ?? user.uid}.';
      });
      widget.onAuthenticated?.call(user);
    } finally {
      // showDialog completes when pop is requested, before its reverse
      // transition has fully removed the TextFields from the widget tree.
      // Keep their controllers alive until that transition has finished.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      phoneController.dispose();
      codeController.dispose();
      if (mounted) setState(() => _isBusy = false);
    }
  }


  Widget _providerButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: _isBusy ? null : onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final radius = BorderRadius.circular(16);

    final content = Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(widget.embedded ? 12 : 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: EdgeInsets.all(widget.embedded ? 20 : 30),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: radius,
              border: Border.all(color: colors.outlineVariant.withValues(alpha: .7)),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: .07),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(Icons.cloud_done_rounded, size: 30, color: colors.primary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isRegistering ? 'Crear cuenta' : 'Iniciar sesión',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRegistering
                        ? 'Regístrate para preparar el acceso a tus tiendas.'
                        : 'Inicia sesión para administrar tu cuenta en la nube.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 26),
                  TextFormField(
                    key: const ValueKey('cloud-auth-email'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    enabled: !_isBusy,
                    decoration: InputDecoration(
                      labelText: 'Correo electrónico',
                      hintText: 'nombre@ejemplo.com',
                      prefixIcon: const Icon(Icons.mail_outline_rounded),
                      filled: true,
                      fillColor: colors.surfaceContainerLowest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide(color: colors.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide(color: colors.outlineVariant),
                      ),
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('cloud-auth-password'),
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    enabled: !_isBusy,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        key: const ValueKey('cloud-auth-toggle-password'),
                        tooltip: _obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                        onPressed: _isBusy ? null : () => setState(() => _obscurePassword = !_obscurePassword),
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                      filled: true,
                      fillColor: colors.surfaceContainerLowest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide(color: colors.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide(color: colors.outlineVariant),
                      ),
                    ),
                    validator: _validatePassword,
                  ),
                  if (!_isRegistering)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isBusy ? null : _resetPassword,
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                    )
                  else
                    const SizedBox(height: 12),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _isBusy ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                    ),
                    child: _isBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _isRegistering ? 'Crear cuenta' : 'Entrar',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(child: Divider(color: colors.outlineVariant)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'O continúa con',
                          style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ),
                      Expanded(child: Divider(color: colors.outlineVariant)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _providerButton(
                    icon: Icons.g_mobiledata_rounded,
                    label: 'Continuar con Google',
                    onPressed: () => _signInWithProvider(
                      authenticate: widget.gateway.signInWithGoogle,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _providerButton(
                          icon: Icons.apple,
                          label: 'Apple',
                          onPressed: () => _signInWithProvider(
                            authenticate: widget.gateway.signInWithApple,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _providerButton(
                          icon: Icons.phone_iphone_rounded,
                          label: 'Teléfono',
                          onPressed: _phoneSignInFlow,
                        ),
                      ),
                    ],
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_isError ? colors.errorContainer : colors.primaryContainer).withValues(alpha: .7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _message!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _isError ? colors.onErrorContainer : colors.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _isRegistering ? '¿Ya tienes una cuenta? ' : '¿No tienes una cuenta? ',
                        style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                      ),
                      TextButton(
                        onPressed: _isBusy ? null : _toggleMode,
                        child: Text(_isRegistering ? 'Inicia sesión' : 'Crear cuenta'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tu punto de venta local seguirá disponible aunque no inicies sesión.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta en la nube')),
      body: content,
    );
  }
}
