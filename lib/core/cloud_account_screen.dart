import 'package:flutter/material.dart';

import 'cloud_auth_gateway.dart';
import 'cloud_auth_screen.dart';

/// Account hub for explicit cloud-account actions.
///
/// This screen is opt-in and is not the POS home route. A signed-in user still
/// needs a separately verified store membership before accessing store data.
class CloudAccountScreen extends StatelessWidget {
  const CloudAccountScreen({
    required this.gateway,
    super.key,
  });

  final CloudAuthGateway gateway;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta en la nube')),
      body: StreamBuilder<CloudAuthUser?>(
        stream: gateway.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.cloud_off_outlined,
              title: 'No se pudo consultar la sesión',
              message:
                  'Comprueba la conexión y la configuración de Firebase. '
                  'La operación local de la tienda sigue disponible.',
              actionLabel: 'Reintentar',
              onAction: () => (context as Element).markNeedsBuild(),
            );
          }

          final user = snapshot.data;
          if (user == null) {
            return _MessageState(
              icon: Icons.person_outline,
              title: 'Sin sesión en la nube',
              message:
                  'Puedes iniciar sesión para preparar el acceso a tus tiendas. '
                  'No es necesario iniciar sesión para usar la caja local.',
              actionLabel: 'Iniciar sesión o crear cuenta',
              onAction: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CloudAuthScreen(gateway: gateway),
                  ),
                );
              },
            );
          }

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 32,
                      child: Icon(Icons.person, size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sesión iniciada',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(user.email ?? user.uid),
                    const SizedBox(height: 16),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'La cuenta confirma tu identidad, pero todavía '
                                'no concede acceso a una tienda. La membresía '
                                'y los permisos se habilitarán después de '
                                'implementar y probar las reglas de seguridad.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () => _signOut(context),
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar sesión en la nube'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await gateway.signOut();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo cerrar la sesión en la nube. La caja local sigue disponible.',
          ),
        ),
      );
    }
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
