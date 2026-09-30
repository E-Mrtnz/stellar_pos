import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/cloud/store_access_models.dart';
import 'package:stellar_pos/core/providers/cloud_access_provider.dart';

class StoreAccessDialog extends StatelessWidget {
  const StoreAccessDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.groups_rounded),
          SizedBox(width: 10),
          Text('Usuarios y dispositivos'),
        ],
      ),
      content: SizedBox(
        width: 760,
        height: 620,
        child: Consumer<CloudAccessProvider>(
          builder: (context, access, _) {
            if (access.isLoading && access.snapshot.users.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (access.errorMessage != null && access.snapshot.users.isEmpty) {
              return Center(child: Text(access.errorMessage!, style: const TextStyle(color: AppColors.dangerRed)));
            }
            if (access.snapshot.users.isEmpty) {
              return const Center(child: Text('Aún no hay usuarios registrados.'));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cada usuario tiene un User ID independiente de sus dispositivos. '
                  'Los dispositivos registrados se muestran dentro de cada usuario.',
                  style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.separated(
                    itemCount: access.snapshot.users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _UserCard(user: access.snapshot.users[index]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        Consumer<CloudAccessProvider>(
          builder: (context, access, _) => TextButton(
            onPressed: access.isLoading ? null : () => access.load(),
            child: const Text('Actualizar'),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
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

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withAlpha(20),
          foregroundColor: AppColors.primary,
          child: Text(
            user.displayName.isEmpty ? '?' : user.displayName.characters.first.toUpperCase(),
          ),
        ),
        title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          'User ID: ${user.userId} · ${roleNameFor(user.roleId)} · ${_statusLabel(user.status)}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Chip(
          label: Text('${devices.length} dispositivo${devices.length == 1 ? '' : 's'}'),
        ),
        children: [
          _RoleAndStatusEditor(user: user, disabled: current && user.roleId == 'owner'),
          const SizedBox(height: 10),
          _PermissionEditor(user: user),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Dispositivos', style: AppTextStyles.sectionTitle.copyWith(fontSize: 13)),
          ),
          const SizedBox(height: 8),
          if (devices.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('No hay dispositivos registrados.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            )
          else
            ...devices.map((device) => _DeviceTile(device: device)),
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
            items: roles.map((role) => DropdownMenuItem(value: role.id, child: Text(role.name))).toList(),
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
    final role = access.snapshot.roles.where((item) => item.id == user.roleId).firstOrNull;
    final defaults = role?.permissions ?? const <String>{};

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Permisos personalizados', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      subtitle: Text('${defaults.length} permisos por defecto del rol', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
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
      'debts': 'Deudas',
      'statistics': 'Estadísticas',
      'settings': 'Configuración',
      'users': 'Usuarios',
      'devices': 'Dispositivos',
    };
    const actionLabels = {
      'view': 'ver',
      'create': 'crear',
      'edit': 'editar',
      'delete': 'eliminar',
      'manage': 'administrar',
      'approve': 'aprobar',
    };
    return '${sectionLabels[section] ?? section}: ${actionLabels[action] ?? action}';
  }
}

class _DeviceTile extends StatelessWidget {
  final StoreDeviceRecord device;
  const _DeviceTile({required this.device});

  @override
  Widget build(BuildContext context) {
    final access = context.watch<CloudAccessProvider>();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            _platformIcon(device.platform),
            color: device.active ? AppColors.successGreen : AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${device.manufacturer} ${device.model}'.trim(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${device.platform} · OS ${device.osVersion} · App ${device.appVersion}',
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
                Text(
                  'Device ID: ${device.deviceId}',
                  style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (device.active)
            TextButton(
              onPressed: () => access.revokeDevice(device.deviceId),
              child: const Text('Revocar'),
            )
          else
            const Chip(label: Text('Revocado')),
        ],
      ),
    );
  }

  IconData _platformIcon(String platform) {
    switch (platform) {
      case 'android':
        return Icons.android_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      case 'macos':
        return Icons.laptop_mac_rounded;
      case 'windows':
        return Icons.desktop_windows_rounded;
      case 'web':
        return Icons.language_rounded;
      default:
        return Icons.devices_other_rounded;
    }
  }
}
