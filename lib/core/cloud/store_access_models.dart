import 'package:cloud_firestore/cloud_firestore.dart';

class StorePermissions {
  static const dashboardView = 'dashboard.view';
  static const salesView = 'sales.view';
  static const salesCreate = 'sales.create';
  static const salesEdit = 'sales.edit';
  static const salesDelete = 'sales.delete';
  static const purchasesView = 'purchases.view';
  static const purchasesCreate = 'purchases.create';
  static const purchasesEdit = 'purchases.edit';
  static const purchasesDelete = 'purchases.delete';
  static const providersView = 'providers.view';
  static const providersCreate = 'providers.create';
  static const providersEdit = 'providers.edit';
  static const providersDelete = 'providers.delete';
  static const productsView = 'products.view';
  static const inventoryView = 'inventory.view';
  static const inventoryCreate = 'inventory.create';
  static const inventoryEdit = 'inventory.edit';
  static const inventoryDelete = 'inventory.delete';
  static const clientsView = 'clients.view';
  static const clientsCreate = 'clients.create';
  static const clientsEdit = 'clients.edit';
  static const clientsDelete = 'clients.delete';
  static const debtsView = 'debts.view';
  static const debtsCreate = 'debts.create';
  static const debtsEdit = 'debts.edit';
  static const debtsDelete = 'debts.delete';
  static const statisticsView = 'statistics.view';
  static const settingsView = 'settings.view';
  static const settingsEdit = 'settings.edit';
  static const usersView = 'users.view';
  static const usersManage = 'users.manage';
  static const devicesView = 'devices.view';
  static const devicesManage = 'devices.manage';

  static const all = <String>{
    dashboardView, salesView, salesCreate, salesEdit, salesDelete,
    purchasesView, purchasesCreate, purchasesEdit, purchasesDelete,
    providersView, providersCreate, providersEdit, providersDelete,
    inventoryView, inventoryCreate, inventoryEdit, inventoryDelete,
    clientsView, clientsCreate, clientsEdit, clientsDelete,
    debtsView, debtsCreate, debtsEdit, debtsDelete,
    statisticsView, settingsView, settingsEdit,
    usersView, usersManage, devicesView, devicesManage,
  };
}

class StoreRoleDefinition {
  final String id;
  final String name;
  final String description;
  final Set<String> permissions;

  const StoreRoleDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.permissions,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'permissions': permissions.toList()..sort(),
      };

  factory StoreRoleDefinition.fromMap(Map<String, dynamic> map) {
    return StoreRoleDefinition(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      permissions: Set<String>.from(
        (map['permissions'] as List?)?.map((e) => e.toString()) ?? const [],
      ),
    );
  }
}

class StoreAccessDefaults {
  static StoreRoleDefinition get owner => const StoreRoleDefinition(
        id: 'owner',
        name: 'Propietario',
        description: 'Acceso completo y administración de la tienda.',
        permissions: StorePermissions.all,
      );

  static StoreRoleDefinition get administrator => StoreRoleDefinition(
        id: 'administrator',
        name: 'Administrador',
        description: 'Administración operativa sin cambiar la propiedad.',
        permissions: StorePermissions.all,
      );

  static StoreRoleDefinition get employee => const StoreRoleDefinition(
        id: 'employee',
        name: 'Empleado',
        description: 'Operación diaria de ventas e inventario.',
        permissions: {
          StorePermissions.dashboardView,
          StorePermissions.salesView,
          StorePermissions.salesCreate,
          StorePermissions.clientsView,
          StorePermissions.clientsCreate,
          StorePermissions.clientsEdit,
          StorePermissions.productsView,
          StorePermissions.inventoryView,
        },
      );

  static StoreRoleDefinition get cashier => const StoreRoleDefinition(
        id: 'cashier',
        name: 'Cajero',
        description: 'Operación de caja y ventas.',
        permissions: {
          StorePermissions.dashboardView,
          StorePermissions.salesView,
          StorePermissions.salesCreate,
          StorePermissions.clientsView,
          StorePermissions.clientsCreate,
          StorePermissions.clientsEdit,
        },
      );

  static StoreRoleDefinition get inventory => const StoreRoleDefinition(
        id: 'inventory',
        name: 'Inventario',
        description: 'Gestión de productos e inventario.',
        permissions: {
          StorePermissions.dashboardView,
          StorePermissions.inventoryView,
          StorePermissions.inventoryCreate,
          StorePermissions.inventoryEdit,
          StorePermissions.productsView,
        },
      );

  static List<StoreRoleDefinition> get all => [
        owner,
        administrator,
        employee,
        cashier,
        inventory,
      ];
}

class StoreUserRecord {
  final String userId;
  final String authUid;
  final String storeId;
  final String displayName;
  final String roleId;
  final String status;
  final String? email;
  final String? invitedByUid;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;
  final Map<String, bool> permissionOverrides;

  const StoreUserRecord({
    required this.userId,
    required this.authUid,
    required this.storeId,
    required this.displayName,
    required this.roleId,
    required this.status,
    this.email,
    this.invitedByUid,
    this.createdAt,
    this.lastSeenAt,
    this.permissionOverrides = const {},
  });

  bool get isActive => status == 'active';

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'authUid': authUid,
        'storeId': storeId,
        'displayName': displayName,
        'roleId': roleId,
        'status': status,
        if (email != null) 'email': email,
        if (invitedByUid != null) 'invitedByUid': invitedByUid,
        'createdAt': createdAt,
        'lastSeenAt': lastSeenAt,
        'permissionOverrides': permissionOverrides,
      };

  factory StoreUserRecord.fromFirestore(
    String id,
    Map<String, dynamic> map,
  ) {
    DateTime? date(dynamic value) =>
        value is Timestamp ? value.toDate() : value is DateTime ? value : null;
    return StoreUserRecord(
      userId: id,
      authUid: map['authUid']?.toString() ?? '',
      storeId: map['storeId']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      roleId: map['roleId']?.toString() ?? 'employee',
      status: map['status']?.toString() ?? 'active',
      email: map['email']?.toString(),
      invitedByUid: map['invitedByUid']?.toString(),
      createdAt: date(map['createdAt']),
      lastSeenAt: date(map['lastSeenAt']),
      permissionOverrides: Map<String, bool>.from(
        (map['permissionOverrides'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value == true),
            ) ??
            const {},
      ),
    );
  }
}

class StoreDeviceRecord {
  final String deviceId;
  final String userId;
  final String storeId;
  final String platform;
  final String osVersion;
  final String manufacturer;
  final String model;
  final String appVersion;
  final DateTime? firstSeenAt;
  final DateTime? lastSeenAt;
  final bool active;
  final String? revokedReason;

  const StoreDeviceRecord({
    required this.deviceId,
    required this.userId,
    required this.storeId,
    required this.platform,
    required this.osVersion,
    required this.manufacturer,
    required this.model,
    required this.appVersion,
    this.firstSeenAt,
    this.lastSeenAt,
    required this.active,
    this.revokedReason,
  });

  Map<String, dynamic> toMap() => {
        'deviceId': deviceId,
        'userId': userId,
        'storeId': storeId,
        'platform': platform,
        'osVersion': osVersion,
        'manufacturer': manufacturer,
        'model': model,
        'appVersion': appVersion,
        'firstSeenAt': firstSeenAt,
        'lastSeenAt': lastSeenAt,
        'active': active,
        if (revokedReason != null) 'revokedReason': revokedReason,
      };

  factory StoreDeviceRecord.fromFirestore(
    String id,
    Map<String, dynamic> map,
  ) {
    DateTime? date(dynamic value) =>
        value is DateTime ? value : (value?.toDate?.call() as DateTime?);
    return StoreDeviceRecord(
      deviceId: id,
      userId: map['userId']?.toString() ?? '',
      storeId: map['storeId']?.toString() ?? '',
      platform: map['platform']?.toString() ?? 'unknown',
      osVersion: map['osVersion']?.toString() ?? 'unknown',
      manufacturer: map['manufacturer']?.toString() ?? 'unknown',
      model: map['model']?.toString() ?? 'unknown',
      appVersion: map['appVersion']?.toString() ?? '',
      firstSeenAt: date(map['firstSeenAt']),
      lastSeenAt: date(map['lastSeenAt']),
      active: map['active'] != false,
      revokedReason: map['revokedReason']?.toString(),
    );
  }

  StoreDeviceRecord copyWith({
    bool? active,
    String? revokedReason,
    DateTime? lastSeenAt,
  }) =>
      StoreDeviceRecord(
        deviceId: deviceId,
        userId: userId,
        storeId: storeId,
        platform: platform,
        osVersion: osVersion,
        manufacturer: manufacturer,
        model: model,
        appVersion: appVersion,
        firstSeenAt: firstSeenAt,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        active: active ?? this.active,
        revokedReason: revokedReason ?? this.revokedReason,
      );
}

class StoreAccessSnapshot {
  final List<StoreUserRecord> users;
  final List<StoreDeviceRecord> devices;
  final List<StoreRoleDefinition> roles;

  const StoreAccessSnapshot({
    required this.users,
    required this.devices,
    required this.roles,
  });

  StoreUserRecord? userById(String id) {
    for (final user in users) {
      if (user.userId == id) return user;
    }
    return null;
  }

  List<StoreDeviceRecord> devicesForUser(String userId) =>
      devices.where((device) => device.userId == userId).toList(growable: false);
}

String roleNameFor(String roleId) {
  for (final role in StoreAccessDefaults.all) {
    if (role.id == roleId) return role.name;
  }
  return roleId;
}
