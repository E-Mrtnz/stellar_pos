class Client {
  final String id;
  final String name;
  final String phone;

  const Client({
    required this.id,
    required this.name,
    required this.phone,
  });

  Client copyWith({String? id, String? name, String? phone}) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'phone': phone};
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
    );
  }
}
