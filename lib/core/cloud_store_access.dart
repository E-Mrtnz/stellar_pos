/// Domain contract for store membership and invitation metadata.
///
/// These values describe the intended authorization model only. They do not
/// grant access by themselves: Firestore Security Rules remain the security
/// boundary, and currently deny all remote reads and writes.
enum StoreRole {
  owner,
  manager,
  cashier,
  viewer;

  /// UI/domain convenience only; never use this as a replacement for rules.
  bool get canManageMembers => this == StoreRole.owner;

  /// UI/domain convenience only; never use this as a replacement for rules.
  bool get canManageSettings =>
      this == StoreRole.owner || this == StoreRole.manager;

  /// UI/domain convenience only; never use this as a replacement for rules.
  bool get canWriteBusinessData =>
      this == StoreRole.owner ||
      this == StoreRole.manager ||
      this == StoreRole.cashier;

  static StoreRole parse(String value) {
    for (final role in StoreRole.values) {
      if (role.name == value) return role;
    }
    throw FormatException('Rol de tienda desconocido: $value');
  }
}

enum StoreMembershipStatus {
  active,
  suspended;

  static StoreMembershipStatus parse(String value) {
    for (final status in StoreMembershipStatus.values) {
      if (status.name == value) return status;
    }
    throw FormatException('Estado de membresía desconocido: $value');
  }
}

/// A user's membership in exactly one store.
///
/// `uid` must be the Firebase Authentication UID. It must not be an email,
/// display name, device ID, or store ID.
class StoreMembership {
  StoreMembership({
    required this.storeId,
    required this.uid,
    required this.role,
    this.status = StoreMembershipStatus.active,
  }) {
    _requireSegment('storeId', storeId);
    _requireSegment('uid', uid);
  }

  final String storeId;
  final String uid;
  final StoreRole role;
  final StoreMembershipStatus status;

  bool get isActive => status == StoreMembershipStatus.active;

  Map<String, Object?> toMap() => <String, Object?>{
        'uid': uid,
        'role': role.name,
        'status': status.name,
      };

  factory StoreMembership.fromMap({
    required String storeId,
    required String uid,
    required Map<String, Object?> data,
  }) {
    final storedUid = data['uid'];
    if (storedUid != uid) {
      throw const FormatException('El UID de membresía no coincide con el documento.');
    }
    final role = data['role'];
    final status = data['status'];
    if (role is! String || status is! String) {
      throw const FormatException('La membresía contiene campos inválidos.');
    }
    return StoreMembership(
      storeId: storeId,
      uid: uid,
      role: StoreRole.parse(role),
      status: StoreMembershipStatus.parse(status),
    );
  }
}

/// Metadata for a short-lived, revocable invitation.
///
/// Only a token hash belongs in a Firestore document. Never persist the
/// human-shareable invitation code itself in this model or remote metadata.
/// Creation/acceptance and use-count updates must be performed by a trusted,
/// transaction-safe flow before invitations can be enabled.
class StoreInvitation {
  StoreInvitation({
    required this.storeId,
    required this.invitationId,
    required this.createdByUid,
    required this.tokenHash,
    required this.role,
    required this.expiresAt,
    this.maxUses = 1,
    this.usesCount = 0,
    this.revoked = false,
  }) {
    _requireSegment('storeId', storeId);
    _requireSegment('invitationId', invitationId);
    _requireSegment('createdByUid', createdByUid);
    _requireSegment('tokenHash', tokenHash);
    if (role == StoreRole.owner) {
      throw ArgumentError.value(role, 'role', 'No se puede invitar a otro propietario.');
    }
    if (maxUses < 1) {
      throw ArgumentError.value(maxUses, 'maxUses', 'Debe ser al menos 1.');
    }
    if (usesCount < 0 || usesCount > maxUses) {
      throw ArgumentError.value(usesCount, 'usesCount', 'Está fuera del límite permitido.');
    }
  }

  final String storeId;
  final String invitationId;
  final String createdByUid;
  final String tokenHash;
  final StoreRole role;
  final DateTime expiresAt;
  final int maxUses;
  final int usesCount;
  final bool revoked;

  bool isUsableAt(DateTime now) =>
      !revoked && now.isBefore(expiresAt) && usesCount < maxUses;

  Map<String, Object?> toMap() => <String, Object?>{
        'createdByUid': createdByUid,
        'tokenHash': tokenHash,
        'role': role.name,
        'expiresAt': expiresAt,
        'maxUses': maxUses,
        'usesCount': usesCount,
        'revoked': revoked,
      };
}

void _requireSegment(String name, String value) {
  if (value.trim().isEmpty || value.contains('/')) {
    throw ArgumentError.value(
      value,
      name,
      'Debe ser un segmento no vacío y no puede contener "/".',
    );
  }
}
