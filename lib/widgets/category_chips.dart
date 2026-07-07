import 'package:flutter/material.dart';

import '../models/category_model.dart';

/// Rangée horizontale de chips de catégories (avec "Toutes"), focusable D-Pad.
class CategoryChips extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  const CategoryChips({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final cat = isAll ? null : categories[index - 1];
          final selected = isAll ? selectedId == null : selectedId == cat!.id;
          return ChoiceChip(
            label: Text(isAll ? 'Toutes' : cat!.name),
            selected: selected,
            onSelected: (_) => onSelected(isAll ? null : cat!.id),
          );
        },
      ),
    );
  }
}
