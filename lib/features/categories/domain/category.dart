class Category {
  final int? id;
  final String name;
  final String? description;

  const Category({this.id, required this.name, this.description});

  factory Category.fromMap(Map<String, Object?> map) => Category(
        id: map['id'] as int,
        name: map['name'] as String,
        description: map['description'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'description': description,
      };
}