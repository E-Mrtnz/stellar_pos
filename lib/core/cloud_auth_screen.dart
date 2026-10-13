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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(widget.embedded ? 8 : 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.cloud_outlined, size: 56, color: colors.primary),
                  const SizedBox(height: 16),
                  Text(
                    _isRegistering ? 'Crear cuenta' : 'Iniciar sesión',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'La cuenta prepara el acceso a tus tiendas. No reemplaza '
                    'la sesión local ni habilita permisos de tienda por sí sola.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const ValueKey('cloud-auth-email'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    enabled: !_isBusy,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('cloud-auth-password'),
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    enabled: !_isBusy,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        key: const ValueKey('cloud-auth-toggle-password'),
                        tooltip: _obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                        onPressed: _isBusy ? null : () => setState(() => _obscurePassword = !_obscurePassword),
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                    ),
                    validator: _validatePassword,
                  ),
                  if (!_isRegistering) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isBusy ? null : _resetPassword,
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                    ),
                  ] else
                    const SizedBox(height: 12),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _isBusy ? null : _submit,
                    child: _isBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isRegistering ? 'Crear cuenta' : 'Entrar'),
                  ),
                  TextButton(
                    onPressed: _isBusy ? null : _toggleMode,
                    child: Text(
                      _isRegistering
                          ? 'Ya tengo una cuenta'
                          : 'Crear una cuenta nueva',
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isError
                              ? colors.error
                              : colors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
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
