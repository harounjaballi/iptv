import 'package:equatable/equatable.dart';

/// Catégorie Xtream (live, VOD ou séries).
class CategoryModel extends Equatable {
  final String id;
  final String name;

  const CategoryModel({required this.id, required this.name});

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['category_id']?.toString() ?? '',
        name: json['category_name']?.toString() ?? 'Sans nom',
      );

  @override
  List<Object?> get props => [id, name];
}
