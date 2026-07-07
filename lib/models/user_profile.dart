import 'package:equatable/equatable.dart';

/// Profil utilisateur (façon Netflix) : les favoris, l'historique,
/// la progression et les statistiques sont propres à chaque profil.
class UserProfile extends Equatable {
  final String id;
  final String name;

  /// Index dans la palette d'avatars (couleur).
  final int colorIndex;

  /// Profil enfant : catégories cachées appliquées, réglages
  /// sensibles protégés par le code PIN parental.
  final bool isKids;

  const UserProfile({
    required this.id,
    required this.name,
    this.colorIndex = 0,
    this.isKids = false,
  });

  /// Profil par défaut (conserve les données existantes du compte).
  static const main = UserProfile(id: 'main', name: 'Principal');

  UserProfile copyWith({String? name, int? colorIndex, bool? isKids}) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        colorIndex: colorIndex ?? this.colorIndex,
        isKids: isKids ?? this.isKids,
      );

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id']?.toString() ?? 'main',
        name: json['name']?.toString() ?? 'Profil',
        colorIndex: int.tryParse(json['color']?.toString() ?? '') ?? 0,
        isKids: json['kids'] == true,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'color': colorIndex, 'kids': isKids};

  /// Initiale affichée dans l'avatar.
  String get initial => name.isEmpty ? '?' : name[0].toUpperCase();

  @override
  List<Object?> get props => [id, name, colorIndex, isKids];
}
