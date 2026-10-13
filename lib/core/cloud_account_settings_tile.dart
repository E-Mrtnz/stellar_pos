import 'package:flutter/material.dart';

import 'cloud_account_screen.dart';
import 'cloud_auth_gateway.dart';

/// A settings entry that opens cloud-account tools only when explicitly tapped.
/// The POS continues to operate locally regardless of authentication state.
class CloudAccountSettingsTile extends StatelessWidget {
  const CloudAccountSettingsTile({
    super.key,
    this.gateway,
  });

  final CloudAuthGateway? gateway;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: const ValueKey('cloud-account-settings-tile'),
      leading: const Icon(Icons.cloud_outlined),
      title: const Text('Cuenta en la nube'),
      subtitle: const Text(
        'Iniciar sesión o administrar tu cuenta. No es necesaria para vender.',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CloudAccountScreen(
              gateway: gateway ?? FirebaseCloudAuth(),
            ),
          ),
        );
      },
    );
  }
}
