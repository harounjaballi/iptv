import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Saisie d'un code PIN à 4 chiffres (création, confirmation, vérification).
/// Retourne le code saisi, ou null si annulé.
Future<String?> showPinInputDialog(
  BuildContext context, {
  required String title,
  String? errorText,
  String cancelLabel = 'Annuler',
  String confirmLabel = 'OK',
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 16),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(counterText: ''),
            onSubmitted: (v) {
              if (v.length == 4) Navigator.of(context).pop(v);
            },
          ),
          if (errorText != null) ...[
            const SizedBox(height: 8),
            Text(errorText,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text.length == 4) {
              Navigator.of(context).pop(controller.text);
            }
          },
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
