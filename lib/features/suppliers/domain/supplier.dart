class Supplier {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;

  const Supplier({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
  });

  factory Supplier.fromMap(Map<String, Object?> map) => Supplier(
        id: map['id'] as int,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        address: map['address'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
      };
}
