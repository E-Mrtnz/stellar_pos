class Client {
  final String id;
  final String name;
  final String phone;
  final String address;

  const Client({
    required this.id,
    required this.name,
    required this.phone,
    this.address = '',
  });

  Client copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
    );
  }
}
