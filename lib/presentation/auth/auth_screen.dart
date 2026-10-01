import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:stellar_pos/core/auth/auth_service.dart';
import 'package:stellar_pos/core/constants/app_constants.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _registerMode = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _working = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_working || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _working = true;
      _error = null;
    });

    try {
      if (_registerMode) {
        await _auth.register(
          displayName: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await _auth.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = _auth.messageForAuthError(error));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo completar la operación: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Escribe tu correo para recuperar la contraseña.');
      return;
    }

    try {
      await _auth.sendPasswordReset(email);
      if (!mounted) return;
      setState(() => _error = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Te enviamos un correo para restablecer tu contraseña.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = _auth.messageForAuthError(error));
    }
  }

  void _toggleMode() {
    setState(() {
      _registerMode = !_registerMode;
      _error = null;
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _registerMode ? 'Crear cuenta' : 'Iniciar sesión';
    final subtitle = _registerMode
        ? 'Crea tu identidad permanente para usar Stellar POS.'
        : 'Accede a tu cuenta para continuar con Stellar POS.';

    return Scaffold(
      backgroundColor: AppColors.inputBackground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              padding: const EdgeInsets.fromLTRB(30, 30, 30, 24),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowColor,
                    blurRadius: 18,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.primary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(title, style: AppTextStyles.brandTitle.copyWith(fontSize: 24)),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (_registerMode) ...[
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Escribe tu nombre.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty || !email.contains('@')) {
                          return 'Escribe un correo válido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction:
                          _registerMode ? TextInputAction.next : TextInputAction.done,
                      onFieldSubmitted: _registerMode ? null : (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').length < 6) {
                          return 'La contraseña debe tener al menos 6 caracteres.';
                        }
                        return null;
                      },
                    ),
                    if (_registerMode) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmation,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Confirmar contraseña',
                          prefixIcon: const Icon(Icons.lock_reset_outlined),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _obscureConfirmation
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            onPressed: () => setState(
                              () => _obscureConfirmation = !_obscureConfirmation,
                            ),
                            icon: Icon(
                              _obscureConfirmation
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Las contraseñas no coinciden.';
                          }
                          return null;
                        },
                      ),
                    ],
                    if (!_registerMode) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _working ? null : _resetPassword,
                          child: const Text('¿Olvidaste tu contraseña?'),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: AppColors.dangerRed.withAlpha(10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.dangerRed.withAlpha(35)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 17,
                              color: AppColors.dangerRed,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.35,
                                  color: AppColors.dangerRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _working ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: _working
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_registerMode ? 'Crear cuenta' : 'Iniciar sesión'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _working ? null : _toggleMode,
                      child: Text(
                        _registerMode
                            ? '¿Ya tienes una cuenta? Inicia sesión'
                            : '¿No tienes una cuenta? Crear cuenta',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
