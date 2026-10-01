import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/cloud/store_access_models.dart';
import 'package:stellar_pos/core/providers/cloud_access_provider.dart';

class StoreAccessDialog extends StatelessWidget {
  const StoreAccessDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 34, vertical: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: 820,
        height: 650,
        child: Consumer<CloudAccessProvider>(
          builder: (context, access, _) {
            return Column(
              children: [
                _AccessHeader(access: access),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                    child: _AccessBody(access: access),
                  ),
                ),
                _AccessFooter(access: access),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AccessHeader extends StatelessWidget {
  final CloudAccessProvider access;
  const _AccessHeader({required this.access});

  @override
  Widget build(BuildContext context) {
    final users = access.snapshot.users.length;
    final devices = access.snapshot.devices.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.groups_rounded, color: AppColors.primary, size: 25),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Usuarios y dispositivos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                SizedBox(height: 3),
                Text(
                  'Gestiona quién puede acceder a esta tienda y desde qué dispositivos.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          _SummaryPill(icon: Icons.person_outline, value: '$users', label: 'usuarios'),
          const SizedBox(width: 8),
          _SummaryPill(icon: Icons.devices_outlined, value: '$devices', label: 'dispositivos'),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _SummaryPill({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _AccessBody extends StatelessWidget {
  final CloudAccessProvider access;
  const _AccessBody({required this.access});

  @override
  Widget build(BuildContext context) {
    if (access.isLoading && access.snapshot.users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (access.errorMessage != null && access.snapshot.users.isEmpty) {
      return _EmptyAccessState(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudieron cargar los usuarios',
        message: 'Comprueba la conexión con la nube y vuelve a intentarlo.',
        action: 'Reintentar',
        onPressed: access.load,
      );
    }

    if (access.snapshot.users.isEmpty) {
      return _EmptyAccessState(
        icon: Icons.person_add_alt_1_outlined,
        title: 'Todavía no hay usuarios',
        message:
            'Cuando se cree o vincule un usuario, aparecerá aquí junto con sus dispositivos, rol y permisos.',
        action: 'Actualizar',
        onPressed: access.load,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withAlpha(28)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'El usuario y el dispositivo son entidades independientes. Una misma persona podrá tener varios dispositivos registrados.',
                  style: TextStyle(fontSize: 11, height: 1.35, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 4),
            itemCount: access.snapshot.users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _UserCard(user: access.snapshot.users[index]),
          ),
        ),
      ],
    );
  }
}

class _EmptyAccessState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String action;
  final VoidCallback onPressed;

  const _EmptyAccessState({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, size: 34, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: AppTextStyles.sectionTitle),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, height: 1.45, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: Text(action),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessFooter extends StatelessWidget {
  final CloudAccessProvider access;
  const _AccessFooter({required this.access});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: access.isLoading ? null : access.load,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Actualizar'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final StoreUserRecord user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final access = context.watch<CloudAccessProvider>();
    final devices = access.snapshot.devicesForUser(user.userId);
    final current = access.currentUser?.userId == user.userId;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        shape: const RoundedRectangleBorder(),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withAlpha(20),
          foregroundColor: AppColors.primary,
          child: Text(
            user.displayName.isEmpty ? '?' : user.displayName.characters.first.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                user.displayName.isEmpty ? 'Usuario sin nombre' : user.displayName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
            if (current) ...[
              const SizedBox(width: 7),
              const _MiniBadge(label: 'Tú'),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            roleNameFor(user.roleId) + ' · ' + _statusLabel(user.status),
            style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
          ),
        ),
        trailing: _MiniBadge(
          label: devices.length.toString() +
              (devices.length == 1 ? ' dispositivo' : ' dispositivos'),
        ),
        children: [
          _RoleAndStatusEditor(user: user, disabled: current),
          const SizedBox(height: 12),
          _PermissionEditor(user: user, disabled: current),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Dispositivos registrados',
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 13),
            ),
          ),
          const SizedBox(height: 7),
          if (devices.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No hay dispositivos registrados.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            )
          else
            ...devices.map((device) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: _DeviceTile(device: device),
                )),
        ],
      ),
    );
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'suspended':
        return 'Suspendido';
      case 'revoked':
        return 'Revocado';
      default:
        return 'Activo';
    }
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  const _MiniBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700)),
    );
  }
}

class _RoleAndStatusEditor extends StatelessWidget {
  final StoreUserRecord user;
  final bool disabled;

  const _RoleAndStatusEditor({
    required this.user,
    required this.disabled,
  });

  Future<void> _showResult(
    BuildContext context,
    CloudAccessProvider access,
    Future<bool> Function() action,
  ) async {
    final ok = await action();
    if (!context.mounted || ok) return;
    final message = access.errorMessage ?? 'No se pudo guardar el cambio.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<CloudAccessProvider>();
    final allRoles = access.snapshot.roles.isEmpty
        ? StoreAccessDefaults.all
        : access.snapshot.roles;
    final roles = allRoles.where((role) => role.id != 'owner').toList(growable: false);

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: roles.any((role) => role.id == user.roleId)
                ? user.roleId
                : null,
            decoration: const InputDecoration(
              labelText: 'Rol',
              helperText: 'Define los permisos base',
              prefixIcon: Icon(Icons.badge_outlined),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: roles
                .map(
                  (role) => DropdownMenuItem(
                    value: role.id,
                    child: Text(role.name),
                  ),
                )
                .toList(),
            onChanged: disabled
                ? null
                : (value) async {
                    if (value == null || value == user.roleId) return;
                    await _showResult(
                      context,
                      access,
                      () => access.changeRole(user.userId, value),
                    );
                  },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: user.status,
            decoration: const InputDecoration(
              labelText: 'Estado',
              helperText: 'Controla si puede operar',
              prefixIcon: Icon(Icons.toggle_on_outlined),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'active', child: Text('Activo')),
              DropdownMenuItem(value: 'suspended', child: Text('Suspendido')),
              DropdownMenuItem(value: 'revoked', child: Text('Revocado')),
            ],
            onChanged: disabled
                ? null
                : (value) async {
                    if (value == null || value == user.status) return;
                    await _showResult(
                      context,
                      access,
                      () => access.changeStatus(user.userId, value),
                    );
                  },
          ),
        ),
      ],
    );
  }
}

class _PermissionEditor extends StatelessWidget {
  final StoreUserRecord user;
  final bool disabled;

  const _PermissionEditor({required this.user, required this.disabled});

  static const _groups = <_PermissionGroup>[
    _PermissionGroup(
      title: 'Inicio y ventas',
      icon: Icons.point_of_sale_rounded,
      permissions: [
        StorePermissions.dashboardView,
        StorePermissions.salesView,
        StorePermissions.salesCreate,
        StorePermissions.salesEdit,
        StorePermissions.salesDelete,
      ],
    ),
    _PermissionGroup(
      title: 'Compras',
      icon: Icons.shopping_bag_outlined,
      permissions: [
        StorePermissions.purchasesView,
        StorePermissions.purchasesCreate,
        StorePermissions.purchasesEdit,
        StorePermissions.purchasesDelete,
      ],
    ),
    _PermissionGroup(
      title: 'Inventario y productos',
      icon: Icons.inventory_2_outlined,
      permissions: [
        StorePermissions.productsView,
        StorePermissions.inventoryView,
        StorePermissions.inventoryCreate,
        StorePermissions.inventoryEdit,
        StorePermissions.inventoryDelete,
      ],
    ),
    _PermissionGroup(
      title: 'Proveedores',
      icon: Icons.local_shipping_outlined,
      permissions: [
        StorePermissions.providersView,
        StorePermissions.providersCreate,
        StorePermissions.providersEdit,
        StorePermissions.providersDelete,
      ],
    ),
    _PermissionGroup(
      title: 'Clientes y cuentas por cobrar',
      icon: Icons.people_outline,
      permissions: [
        StorePermissions.clientsView,
        StorePermissions.clientsCreate,
        StorePermissions.clientsEdit,
        StorePermissions.clientsDelete,
        StorePermissions.debtsView,
        StorePermissions.debtsCreate,
        StorePermissions.debtsEdit,
        StorePermissions.debtsDelete,
      ],
    ),
    _PermissionGroup(
      title: 'Estadísticas y ajustes',
      icon: Icons.analytics_outlined,
      permissions: [
        StorePermissions.statisticsView,
        StorePermissions.settingsView,
        StorePermissions.settingsEdit,
      ],
    ),
    _PermissionGroup(
      title: 'Usuarios y dispositivos',
      icon: Icons.admin_panel_settings_outlined,
      permissions: [
        StorePermissions.usersView,
        StorePermissions.usersManage,
        StorePermissions.devicesView,
        StorePermissions.devicesManage,
      ],
    ),
  ];

  StoreRoleDefinition? _roleFor(
    CloudAccessProvider access,
    String roleId,
  ) {
    for (final role in access.snapshot.roles) {
      if (role.id == roleId) return role;
    }
    for (final role in StoreAccessDefaults.all) {
      if (role.id == roleId) return role;
    }
    return null;
  }

  String _permissionTitle(String permission) {
    const labels = {
      'dashboard.view': 'Ver inicio',
      'sales.view': 'Ver ventas',
      'sales.create': 'Crear ventas',
      'sales.edit': 'Editar ventas',
      'sales.delete': 'Eliminar ventas',
      'purchases.view': 'Ver compras',
      'purchases.create': 'Crear compras',
      'purchases.edit': 'Editar compras',
      'purchases.delete': 'Eliminar compras',
      'products.view': 'Ver productos',
      'inventory.view': 'Ver inventario',
      'inventory.create': 'Crear productos',
      'inventory.edit': 'Editar productos',
      'inventory.delete': 'Eliminar productos',
      'providers.view': 'Ver proveedores',
      'providers.create': 'Crear proveedores',
      'providers.edit': 'Editar proveedores',
      'providers.delete': 'Eliminar proveedores',
      'clients.view': 'Ver clientes',
      'clients.create': 'Crear clientes',
      'clients.edit': 'Editar clientes',
      'clients.delete': 'Eliminar clientes',
      'debts.view': 'Ver cuentas por cobrar',
      'debts.create': 'Crear cuentas por cobrar',
      'debts.edit': 'Editar cuentas por cobrar',
      'debts.delete': 'Eliminar cuentas por cobrar',
      'statistics.view': 'Ver estadísticas',
      'settings.view': 'Ver ajustes',
      'settings.edit': 'Editar ajustes',
      'users.view': 'Ver usuarios',
      'users.manage': 'Administrar usuarios',
      'devices.view': 'Ver dispositivos',
      'devices.manage': 'Administrar dispositivos',
    };
    return labels[permission] ?? permission;
  }

  Future<void> _togglePermission(
    BuildContext context,
    CloudAccessProvider access,
    String permission,
    bool enabled,
  ) async {
    final ok = await access.changePermission(user.userId, permission, enabled);
    if (!context.mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          access.errorMessage ?? 'No se pudo guardar el permiso.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _resetPermission(
    BuildContext context,
    CloudAccessProvider access,
    String permission,
  ) async {
    final ok = await access.resetPermission(user.userId, permission);
    if (!context.mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          access.errorMessage ?? 'No se pudo restaurar el permiso.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<CloudAccessProvider>();
    final role = _roleFor(access, user.roleId);
    final defaults = role?.permissions ?? const <String>{};
    final overrides = user.permissionOverrides;
    final activeCount = StorePermissions.all.where((permission) {
      return overrides.containsKey(permission)
          ? overrides[permission] == true
          : defaults.contains(permission);
    }).length;

    final subtitle = overrides.isEmpty
        ? 'Usando únicamente los permisos del rol ' + roleNameFor(user.roleId)
        : overrides.length.toString() +
            ' permisos personalizados · puedes restaurarlos al rol';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        title: Row(
          children: [
            const Icon(
              Icons.tune_rounded,
              size: 19,
              color: AppColors.primary,
            ),
            const SizedBox(width: 9),
            const Expanded(
              child: Text(
                'Permisos personalizados',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _MiniBadge(label: activeCount.toString() + ' activos'),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 28, top: 3),
          child: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          ..._groups.map(
            (group) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PermissionGroupCard(
                group: group,
                defaults: defaults,
                overrides: overrides,
                titleFor: _permissionTitle,
                onChanged: (permission, value) =>
                    _togglePermission(context, access, permission, value),
                onReset: (permission) =>
                    _resetPermission(context, access, permission),
              ),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Activado sin etiqueta = heredado del rol. '
            '“Personalizado” = valor guardado específicamente para este usuario.',
            style: TextStyle(
              fontSize: 10,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionGroup {
  final String title;
  final IconData icon;
  final List<String> permissions;

  const _PermissionGroup({
    required this.title,
    required this.icon,
    required this.permissions,
  });
}

class _PermissionGroupCard extends StatelessWidget {
  final _PermissionGroup group;
  final Set<String> defaults;
  final Map<String, bool> overrides;
  final String Function(String) titleFor;
  final Future<void> Function(String, bool) onChanged;
  final Future<void> Function(String) onReset;

  const _PermissionGroupCard({
    required this.group,
    required this.defaults,
    required this.overrides,
    required this.titleFor,
    required this.onChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final active = group.permissions.where(
      (permission) => overrides.containsKey(permission)
          ? overrides[permission] == true
          : defaults.contains(permission),
    ).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(group.icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                active.toString() + '/' + group.permissions.length.toString(),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ...group.permissions.map(
            (permission) {
              final custom = overrides.containsKey(permission);
              final enabled = custom
                  ? overrides[permission] == true
                  : defaults.contains(permission);
              return Container(
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: custom
                      ? AppColors.primary.withAlpha(10)
                      : AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: custom
                        ? AppColors.primary.withAlpha(35)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SwitchListTile.adaptive(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 0,
                        ),
                        title: Text(
                          titleFor(permission),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          custom ? 'Personalizado' : 'Heredado del rol',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: custom
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                        value: enabled,
                        onChanged: disabled
                            ? null
                            : (value) => onChanged(permission, value),
                      ),
                    ),
                    if (custom)
                      IconButton(
                        tooltip: 'Restaurar valor del rol',
                        onPressed: disabled ? null : () => onReset(permission),
                        icon: const Icon(
                          Icons.restart_alt_rounded,
                          size: 18,
                        ),
                        color: AppColors.textSecondary,
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final StoreDeviceRecord device;
  const _DeviceTile({required this.device});

  @override
  Widget build(BuildContext context) {
    final access = context.read<CloudAccessProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(16),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(_platformIcon(device.platform), color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.model.isEmpty ? device.platform : device.model,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  device.platform + ' · ' + device.osVersion + ' · App ' + device.appVersion,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          _MiniBadge(label: device.active ? 'Activo' : 'Revocado'),
          const SizedBox(width: 7),
          if (device.active)
            IconButton(
              tooltip: 'Revocar dispositivo',
              onPressed: () async {
                await access.revokeDevice(device.deviceId);
              },
              icon: const Icon(Icons.block_outlined, size: 18),
            ),
        ],
      ),
    );
  }

  IconData _platformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'macos':
        return Icons.laptop_mac_outlined;
      case 'windows':
        return Icons.desktop_windows_outlined;
      case 'android':
        return Icons.phone_android_outlined;
      case 'ios':
        return Icons.phone_iphone_outlined;
      case 'web':
        return Icons.language_outlined;
      default:
        return Icons.devices_other_outlined;
    }
  }
}
