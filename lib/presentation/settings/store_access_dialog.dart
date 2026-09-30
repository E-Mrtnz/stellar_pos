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
          _RoleAndStatusEditor(user: user, disabled: current && user.roleId == 'owner'),
          const SizedBox(height: 12),
          _PermissionEditor(user: user),
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
  const _RoleAndStatusEditor({required this.user, required this.disabled});

  @override
  Widget build(BuildContext context) {
    final access = context.watch<CloudAccessProvider>();
    final roles = access.snapshot.roles.isEmpty ? StoreAccessDefaults.all : access.snapshot.roles;

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: user.roleId,
            decoration: const InputDecoration(
              labelText: 'Rol',
              prefixIcon: Icon(Icons.badge_outlined),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: roles
                .map((role) => DropdownMenuItem(value: role.id, child: Text(role.name)))
                .toList(),
            onChanged: disabled
                ? null
                : (value) async {
                    if (value == null || value == user.roleId) return;
                    await access.changeRole(user.userId, value);
                  },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: user.status,
            decoration: const InputDecoration(
              labelText: 'Estado',
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
                    await access.changeStatus(user.userId, value);
                  },
          ),
        ),
      ],
    );
  }
}

class _PermissionEditor extends StatelessWidget {
  final StoreUserRecord user;
  const _PermissionEditor({required this.user});

  @override
  Widget build(BuildContext context) {
    final access = context.watch<CloudAccessProvider>();
    StoreRoleDefinition? role;
    for (final candidate in access.snapshot.roles) {
      if (candidate.id == user.roleId) {
        role = candidate;
        break;
      }
    }
    final defaults = role?.permissions ?? const <String>{};

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8),
        title: const Text(
          'Permisos personalizados',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          defaults.length.toString() + ' permisos por defecto del rol',
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: StorePermissions.all.map((permission) {
              final override = user.permissionOverrides.containsKey(permission)
                  ? user.permissionOverrides[permission]
                  : null;
              final effective = override ?? defaults.contains(permission);
              return FilterChip(
                label: Text(_permissionLabel(permission)),
                selected: effective,
                onSelected: (selected) async {
                  await access.changePermission(user.userId, permission, selected);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Un permiso personalizado sustituye el valor predeterminado del rol.',
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  String _permissionLabel(String permission) {
    final parts = permission.split('.');
    final section = parts.first;
    final action = parts.length > 1 ? parts[1] : '';
    const sectionLabels = {
      'dashboard': 'Inicio',
      'sales': 'Ventas',
      'products': 'Productos',
      'purchases': 'Compras',
      'providers': 'Proveedores',
      'inventory': 'Inventario',
      'clients': 'Clientes',
      'debts': 'Cuentas por cobrar',
      'statistics': 'Estadísticas',
      'settings': 'Ajustes',
      'users': 'Usuarios',
      'devices': 'Dispositivos',
    };
    const actionLabels = {
      'view': 'ver',
      'create': 'crear',
      'edit': 'editar',
      'delete': 'eliminar',
      'manage': 'administrar',
    };
    return (sectionLabels[section] ?? section) +
        (action.isEmpty ? '' : ' · ' + (actionLabels[action] ?? action));
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
