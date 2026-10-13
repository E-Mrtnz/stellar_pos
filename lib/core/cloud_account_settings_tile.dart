import 'package:flutter/material.dart';

import 'cloud_auth_gateway.dart';
import 'cloud_auth_screen.dart';

/// Inline cloud account panel. Cloud identity never grants store membership.
class CloudAccountSettingsTile extends StatefulWidget {
  const CloudAccountSettingsTile({super.key, this.gateway});

  final CloudAuthGateway? gateway;

  @override
  State<CloudAccountSettingsTile> createState() => _CloudAccountSettingsTileState();
}

class _CloudAccountSettingsTileState extends State<CloudAccountSettingsTile> {
  bool _expanded = true;
  int _streamVersion = 0;
  late final CloudAuthGateway _gateway = widget.gateway ?? FirebaseCloudAuth();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        ListTile(
          key: const ValueKey('cloud-account-settings-tile'),
          leading: Icon(Icons.cloud_outlined, color: colors.primary),
          title: const Text('Cuenta en la nube'),
          subtitle: const Text(
            'Inicia sesión o administra tu cuenta. No es necesaria para vender.',
          ),
          trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: StreamBuilder<CloudAuthUser?>(
              key: ValueKey(_streamVersion),
              stream: _gateway.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return _InlineNotice(
                    message: 'No se pudo consultar la sesión. La caja local sigue disponible.',
                    action: TextButton(
                      onPressed: () => setState(() => _streamVersion++),
                      child: const Text('Reintentar'),
                    ),
                  );
                }
                final user = snapshot.data;
                if (user == null) {
                  return CloudAuthScreen(
                    gateway: _gateway,
                    embedded: true,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: colors.primaryContainer,
                          child: Icon(Icons.person_outline, color: colors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Sesión iniciada', style: TextStyle(fontWeight: FontWeight.w700)),
                              SelectableText(user.email ?? user.uid),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _InlineNotice(
                      message: 'La cuenta confirma tu identidad, pero todavía no concede acceso a una tienda.',
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Cerrar sesión'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _signOut() async {
    try {
      await _gateway.signOut();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cerrar la sesión. La caja local sigue disponible.')),
      );
    }
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 19),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
          if (action != null) action!,
        ],
      ),
    );
  }
}
