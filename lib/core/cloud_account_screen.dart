import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

import 'cloud_auth_gateway.dart';
import 'cloud_auth_screen.dart';
import 'cloud_store_repository.dart';
import 'cloud_active_store_selection.dart';

/// Account hub for explicit cloud-account and store-creation actions.
///
/// This screen is opt-in and is not the POS home route. Creating a shared store
/// does not upload or synchronize local business data.
class CloudAccountScreen extends StatefulWidget {
  const CloudAccountScreen({
    required this.gateway,
    this.storeGateway,
    this.invitationGateway,
    this.activeStoreSelection,
    super.key,
  });

  final CloudAuthGateway gateway;
  final CloudStoreGateway? storeGateway;
  final CloudInvitationGateway? invitationGateway;
  final ActiveCloudStoreSelection? activeStoreSelection;

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
            invitationGateway: widget.invitationGateway ??
                (_storeGateway is CloudInvitationGateway
                    ? _storeGateway as CloudInvitationGateway
                    : CloudStoreRepository()),
            activeStoreSelection: widget.activeStoreSelection ??
                SharedPreferencesActiveCloudStoreSelection(),
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
    required this.invitationGateway,
    required this.activeStoreSelection,
    super.key,
  });

  final CloudAuthUser user;
  final CloudAuthGateway authGateway;
  final CloudStoreGateway storeGateway;
  final CloudInvitationGateway invitationGateway;
  final ActiveCloudStoreSelection activeStoreSelection;

  @override
  State<_SignedInCloudPanel> createState() => _SignedInCloudPanelState();
}

class _SignedInCloudPanelState extends State<_SignedInCloudPanel> {
  final _storeNameController = TextEditingController();
  bool _creatingStore = false;
  String? _errorMessage;
  late Future<List<CloudStore>> _storesFuture;
  String? _selectedStoreId;
  final _joinStoreIdController = TextEditingController();
  final _joinCodeController = TextEditingController();
  String _invitationRole = 'cashier';
  bool _invitationBusy = false;
  bool _acceptingInvitation = false;
  String? _invitationCode;
  String? _invitationMessage;

  @override
  void initState() {
    super.initState();
    _storesFuture = widget.storeGateway.listMyStores();
    _restoreSelectedStore();
  }

  Future<void> _restoreSelectedStore() async {
    try {
      final saved = await widget.activeStoreSelection.read(widget.user.uid);
      if (!mounted || saved == null) return;
      final stores = await _storesFuture;
      if (!mounted || !stores.any((store) => store.id == saved)) return;
      setState(() => _selectedStoreId = saved);
    } catch (_) {
      // A stale/unavailable preference must never prevent local checkout.
    }
  }

  Future<void> _selectStore(String? storeId) async {
    if (storeId == null) return;
    setState(() => _selectedStoreId = storeId);
    await _persistSelectedStore(storeId);
  }

  Future<void> _persistSelectedStore(String storeId) async {
    try {
      await widget.activeStoreSelection.write(widget.user.uid, storeId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la tienda seleccionada en este dispositivo.')),
      );
    }
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
    _joinStoreIdController.dispose();
    _joinCodeController.dispose();
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
      await _persistSelectedStore(store.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (error is FirebaseException &&
            (error.code == 'permission-denied' || error.code == 'unauthorized')) {
          _errorMessage = 'Firebase rechazó la creación por permisos (${error.code}). Comprueba que las reglas de firestore.rules estén desplegadas en el proyecto stellar-pos-86f0c y que hayas iniciado sesión con la cuenta correcta. Tus datos locales no se han modificado.';
        } else if (error is FirebaseException &&
            (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
          _errorMessage = 'Firebase no está disponible por ahora. Comprueba tu conexión y vuelve a intentarlo. Tus datos locales no se han modificado.';
        } else if (error.toString().contains('Firebase no está disponible')) {
          _errorMessage = 'Firebase no pudo inicializarse. Verifica la configuración de Firebase para macOS. La caja local sigue disponible.';
        } else {
          _errorMessage = 'No se pudo crear la tienda. Comprueba la conexión y la configuración de Firestore; tus datos locales no se han modificado.';
        }
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
                  return RadioGroup<String>(
                    groupValue: _selectedStoreId,
                    onChanged: _selectStore,
                    child: Column(
                    children: [
                      for (final store in stores)
                        Card(
                          child: RadioListTile<String>(
                            value: store.id,
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
                              'Tienda seleccionada: ${stores.where((s) => s.id == _selectedStoreId).map((s) => s.name).join()}\n'
                              'La selección se guarda en este dispositivo. Todavía no cambia la caja ni activa sincronización comercial.',
                            ),
                          ),
                        ),
                    ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Compartir una tienda',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Solo el propietario de la tienda puede generar una invitación. '
                        'El código se muestra una sola vez; compártelo únicamente con la persona autorizada.',
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _invitationRole,
                        decoration: const InputDecoration(
                          labelText: 'Permiso de la persona invitada',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'manager', child: Text('Administrador')),
                          DropdownMenuItem(value: 'cashier', child: Text('Cajero')),
                          DropdownMenuItem(value: 'viewer', child: Text('Solo lectura')),
                        ],
                        onChanged: _invitationBusy ? null : (value) {
                          if (value != null) setState(() => _invitationRole = value);
                        },
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _invitationBusy || _selectedStoreId == null
                            ? null
                            : _createInvitation,
                        icon: _invitationBusy
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.person_add_alt_1),
                        label: Text(_invitationBusy
                            ? 'Generando código…'
                            : 'Generar invitación para la tienda seleccionada'),
                      ),
                      if (_invitationCode != null) ...[
                        const SizedBox(height: 12),
                        const Text('Código de invitación (cópialo ahora):'),
                        SelectableText(
                          _invitationCode!,
                          key: const ValueKey('store-invitation-code'),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await Clipboard.setData(ClipboardData(text: _invitationCode!));
                            if (!mounted) return;
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Código copiado.')),
                            );
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Copiar código'),
                        ),
                        TextButton.icon(
                          onPressed: _invitationBusy ? null : _revokeInvitation,
                          icon: const Icon(Icons.link_off),
                          label: const Text('Revocar código'),
                        ),
                      ],
                      const Divider(height: 28),
                      Text(
                        'Unirse a una tienda',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _joinStoreIdController,
                        decoration: const InputDecoration(
                          labelText: 'ID de la tienda',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _joinCodeController,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Código de invitación',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _acceptingInvitation ? null : _acceptInvitation,
                        icon: _acceptingInvitation
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.group_add_outlined),
                        label: Text(_acceptingInvitation
                            ? 'Validando invitación…'
                            : 'Aceptar invitación'),
                      ),
                      if (_invitationMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _invitationMessage!,
                          key: const ValueKey('store-invitation-message'),
                          style: TextStyle(
                            color: _invitationMessage!.startsWith('Error:')
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Crear una tienda',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('store-name-field'),
                controller: _storeNameController,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                enabled: !_creatingStore,
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
                onPressed: _creatingStore ? null : _createStore,
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


  Future<void> _createInvitation() async {
    final storeId = _selectedStoreId;
    if (_invitationBusy || storeId == null) return;
    setState(() {
      _invitationBusy = true;
      _invitationMessage = null;
      _invitationCode = null;
    });
    try {
      final invitation = await widget.invitationGateway.createInvitation(
        storeId: storeId,
        role: _invitationRole,
      );
      if (!mounted) return;
      setState(() {
        _invitationCode = invitation.code;
        _invitationMessage =
            'Invitación válida hasta ${invitation.expiresAt.toLocal()}.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _invitationMessage =
          'Error: no se pudo generar la invitación. Comprueba que seas propietario y que las funciones estén desplegadas.');
    } finally {
      if (mounted) setState(() => _invitationBusy = false);
    }
  }

  Future<void> _revokeInvitation() async {
    final storeId = _selectedStoreId;
    final code = _invitationCode;
    if (_invitationBusy || storeId == null || code == null) return;
    setState(() { _invitationBusy = true; _invitationMessage = null; });
    try {
      await widget.invitationGateway.revokeInvitation(
        storeId: storeId,
        invitationCode: code,
      );
      if (!mounted) return;
      setState(() {
        _invitationCode = null;
        _invitationMessage = 'Invitación revocada; el código ya no se puede usar.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _invitationMessage =
          'Error: no se pudo revocar el código. Comprueba que seas propietario y que las funciones estén desplegadas.');
    } finally {
      if (mounted) setState(() => _invitationBusy = false);
    }
  }

  Future<void> _acceptInvitation() async {
    if (_acceptingInvitation) return;
    final storeId = _joinStoreIdController.text.trim();
    final code = _joinCodeController.text.trim();
    if (storeId.isEmpty || code.isEmpty) {
      setState(() => _invitationMessage =
          'Error: introduce el ID de la tienda y el código.');
      return;
    }
    setState(() {
      _acceptingInvitation = true;
      _invitationMessage = null;
    });
    try {
      final accepted = await widget.invitationGateway.acceptInvitation(
        storeId: storeId,
        invitationCode: code,
      );
      if (!mounted) return;
      setState(() {
        _joinStoreIdController.clear();
        _joinCodeController.clear();
        _selectedStoreId = accepted.storeId;
        _storesFuture = widget.storeGateway.listMyStores();
        _invitationMessage =
            'Te uniste a la tienda con el rol: ${accepted.role}.';
      });
      await _persistSelectedStore(accepted.storeId);
    } catch (error) {
      if (!mounted) return;
      setState(() => _invitationMessage =
          'Error: la invitación no se pudo aceptar. Puede haber vencido, agotado sus usos o no corresponder a esa tienda.');
    } finally {
      if (mounted) setState(() => _acceptingInvitation = false);
    }
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
