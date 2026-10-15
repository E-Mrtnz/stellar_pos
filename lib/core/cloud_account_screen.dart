import 'package:flutter/material.dart';

import 'cloud_auth_gateway.dart';
import 'cloud_auth_screen.dart';
import 'cloud_store_repository.dart';

/// Account hub for explicit cloud-account and store-creation actions.
///
/// This screen is opt-in and is not the POS home route. Creating a shared store
/// does not upload or synchronize local business data.
class CloudAccountScreen extends StatefulWidget {
  const CloudAccountScreen({
    required this.gateway,
    this.storeGateway,
    super.key,
  });

  final CloudAuthGateway gateway;
  final CloudStoreGateway? storeGateway;

  @override
  State<CloudAccountScreen> createState() => _CloudAccountScreenState();
}

class _CloudAccountScreenState extends State<CloudAccountScreen> {
  int _streamVersion = 0;
  late final CloudStoreGateway _storeGateway =
      widget.storeGateway ?? CloudStoreRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta en la nube')),
      body: StreamBuilder<CloudAuthUser?>(
        key: ValueKey(_streamVersion),
        stream: widget.gateway.authStateChanges(),
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
              onAction: () => setState(() => _streamVersion++),
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
                    builder: (_) => CloudAuthScreen(gateway: widget.gateway),
                  ),
                );
              },
            );
          }

          return _SignedInCloudPanel(
            key: ValueKey(user.uid),
            user: user,
            authGateway: widget.gateway,
            storeGateway: _storeGateway,
          );
        },
      ),
    );
  }
}

class _SignedInCloudPanel extends StatefulWidget {
  const _SignedInCloudPanel({
    required this.user,
    required this.authGateway,
    required this.storeGateway,
    super.key,
  });

  final CloudAuthUser user;
  final CloudAuthGateway authGateway;
  final CloudStoreGateway storeGateway;

  @override
  State<_SignedInCloudPanel> createState() => _SignedInCloudPanelState();
}

class _SignedInCloudPanelState extends State<_SignedInCloudPanel> {
  final _storeNameController = TextEditingController();
  bool _creatingStore = false;
  String? _errorMessage;
  late Future<List<CloudStore>> _storesFuture;
  String? _selectedStoreId;

  @override
  void initState() {
    super.initState();
    _storesFuture = widget.storeGateway.listMyStores();
  }

  void _reloadStores() {
    setState(() {
      _storesFuture = widget.storeGateway.listMyStores();
    });
  }
  CloudStore? _createdStore;

  @override
  void dispose() {
    _storeNameController.dispose();
    super.dispose();
  }

  Future<void> _createStore() async {
    if (_creatingStore) return;
    if (_storeNameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Escribe el nombre de la tienda.';
      });
      return;
    }
    setState(() {
      _creatingStore = true;
      _errorMessage = null;
    });

    try {
      final store = await widget.storeGateway.createStore(
        name: _storeNameController.text,
      );
      if (!mounted) return;
      setState(() {
        _createdStore = store;
        _selectedStoreId = store.id;
        _storeNameController.clear();
        _storesFuture = widget.storeGateway.listMyStores();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No se pudo crear la tienda. Comprueba la conexión y que las '
            'reglas de Firestore estén desplegadas; tus datos locales no se '
            'han modificado.';
      });
    } finally {
      if (mounted) setState(() => _creatingStore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CircleAvatar(
                radius: 32,
                child: Icon(Icons.person, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'Sesión iniciada',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              SelectableText(
                widget.user.email ?? widget.user.uid,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
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
                          'Una tienda de Stellar POS es un espacio de datos '
                          'compartido, no una página de comercio electrónico. '
                          'Crear una tienda no sube tus productos ni tus ventas.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Mis tiendas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<CloudStore>>(
                future: _storesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('No se pudieron recuperar tus tiendas.'),
                            const SizedBox(height: 8),
                            const Text(
                              'Comprueba la conexión y las reglas de Firestore. '
                              'No se ha modificado ningún dato local.',
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _reloadStores,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reintentar'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final stores = snapshot.data ?? const <CloudStore>[];
                  if (stores.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Todavía no tienes tiendas vinculadas a esta cuenta. '
                          'Puedes crear una aquí. La opción para unirte a una '
                          'tienda existente estará disponible cuando se implemente '
                          'el flujo seguro de invitaciones.',
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final store in stores)
                        Card(
                          child: RadioListTile<String>(
                            value: store.id,
                            groupValue: _selectedStoreId,
                            onChanged: (value) {
                              setState(() => _selectedStoreId = value);
                            },
                            title: Text(store.name),
                            subtitle: SelectableText('ID: ${store.id}'),
                            secondary: Icon(
                              store.ownerUid == widget.user.uid
                                  ? Icons.storefront_outlined
                                  : Icons.store_outlined,
                            ),
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _reloadStores,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Actualizar lista'),
                        ),
                      ),
                      if (_selectedStoreId != null)
                        Card(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Tienda seleccionada: ${stores.where((s) => s.id == _selectedStoreId).map((s) => s.name).join()}\\n'
                              'Esta selección es visual por ahora; todavía no cambia la caja ni activa sincronización.',
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Crear una tienda',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _storeNameController,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                enabled: !_creatingStore && _createdStore == null,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la tienda',
                  hintText: 'Ej. Tienda El Edén',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _creatingStore || _createdStore != null
                    ? null
                    : _createStore,
                icon: _creatingStore
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_business_outlined),
                label: Text(
                  _creatingStore ? 'Creando tienda…' : 'Crear tienda',
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  key: const ValueKey('create-store-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_createdStore != null) ...[
                const SizedBox(height: 16),
                Card(
                  key: const ValueKey('created-store-result'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle_outline),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tienda creada',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_createdStore!.name),
                        const SizedBox(height: 4),
                        const Text('Identificador de tienda'),
                        SelectableText(
                          _createdStore!.id,
                          key: const ValueKey('created-store-id'),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'La tienda está creada, pero todavía no se han '
                          'sincronizado productos, ventas ni otros datos.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await widget.authGateway.signOut();
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
