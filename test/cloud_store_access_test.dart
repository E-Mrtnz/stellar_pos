import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_store_access.dart';

void main() {
  group('StoreRole', () {
    test('permissions are scoped to the intended role', () {
      expect(StoreRole.owner.canManageMembers, isTrue);
      expect(StoreRole.manager.canManageMembers, isFalse);
      expect(StoreRole.manager.canManageSettings, isTrue);
      expect(StoreRole.cashier.canWriteBusinessData, isTrue);
      expect(StoreRole.viewer.canWriteBusinessData, isFalse);
    });

    test('rejects unknown role values', () {
      expect(() => StoreRole.parse('admin'), throwsFormatException);
    });
  });

  group('StoreMembership', () {
    test('round-trips role and status metadata', () {
      final membership = StoreMembership(
        storeId: 'store-a',
        uid: 'user-a',
        role: StoreRole.cashier,
      );

      final restored = StoreMembership.fromMap(
        storeId: 'store-a',
        uid: 'user-a',
        data: membership.toMap(),
      );

      expect(restored.storeId, 'store-a');
      expect(restored.uid, 'user-a');
      expect(restored.role, StoreRole.cashier);
      expect(restored.isActive, isTrue);
    });

    test('rejects a UID that differs from the document identity', () {
      expect(
        () => StoreMembership.fromMap(
          storeId: 'store-a',
          uid: 'user-a',
          data: <String, Object?>{
            'uid': 'user-b',
            'role': 'owner',
            'status': 'active',
          },
        ),
        throwsFormatException,
      );
    });

    test('rejects malformed identifiers', () {
      expect(
        () => StoreMembership(
          storeId: 'store/a',
          uid: 'user-a',
          role: StoreRole.owner,
        ),
        throwsArgumentError,
      );
    });
  });

  group('StoreInvitation', () {
    final expiresAt = DateTime.utc(2030, 1, 1);

    test('is usable only before expiry, while not revoked and below use limit', () {
      final invitation = StoreInvitation(
        storeId: 'store-a',
        invitationId: 'invite-a',
        createdByUid: 'owner-a',
        tokenHash: 'hash-only',
        role: StoreRole.cashier,
        expiresAt: expiresAt,
        maxUses: 2,
        usesCount: 1,
      );

      expect(invitation.isUsableAt(DateTime.utc(2029, 12, 31)), isTrue);
      expect(invitation.isUsableAt(expiresAt), isFalse);
      expect(
        StoreInvitation(
          storeId: 'store-a',
          invitationId: 'invite-b',
          createdByUid: 'owner-a',
          tokenHash: 'hash-only',
          role: StoreRole.cashier,
          expiresAt: expiresAt,
          maxUses: 1,
          usesCount: 1,
        ).isUsableAt(DateTime.utc(2029, 12, 31)),
        isFalse,
      );
    });

    test('never serializes a raw invitation code', () {
      final invitation = StoreInvitation(
        storeId: 'store-a',
        invitationId: 'invite-a',
        createdByUid: 'owner-a',
        tokenHash: 'hash-only',
        role: StoreRole.viewer,
        expiresAt: expiresAt,
      );

      expect(invitation.toMap().containsKey('code'), isFalse);
      expect(invitation.toMap()['tokenHash'], 'hash-only');
    });

    test('does not allow invitations to grant owner role', () {
      expect(
        () => StoreInvitation(
          storeId: 'store-a',
          invitationId: 'invite-a',
          createdByUid: 'owner-a',
          tokenHash: 'hash-only',
          role: StoreRole.owner,
          expiresAt: expiresAt,
        ),
        throwsArgumentError,
      );
    });
  });
}
