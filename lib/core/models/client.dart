import 'package:stellar_pos/core/models/sync_metadata.dart';

class Client implements SyncableEntity {
  @override
  final String id;
  final String name;
  final String phone;
  final String address;
  @override
  final SyncMetadata metadata;

  Client({
    required this.id,
    required this.name,
    required this.phone,
    this.address = '',
    SyncMetadata? metadata,
  }) : metadata = metadata ?? SyncMetadata.initial();

  Client copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    SyncMetadata? metadata,
    bool touchMetadata = true,
  }) => Client(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        metadata: metadata ??
            (touchMetadata ? this.metadata.touch() : this.metadata),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'metadata': metadata.toMap(),
      };

  factory Client.fromMap(Map<String, dynamic> map) => Client(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        phone: map['phone']?.toString() ?? '',
        address: map['address']?.toString() ?? '',
        metadata: _metadata(map['metadata']),
      );

  static SyncMetadata _metadata(dynamic value) => value is Map
      ? SyncMetadata.fromMap(Map<String, dynamic>.from(value))
      : SyncMetadata.initial();
}
