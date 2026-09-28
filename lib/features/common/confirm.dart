import 'package:flutter/material.dart';

/// A yes/no confirmation, as one function.
///
/// It exists for one reason beyond convenience: the repository's rule is that a
/// file which builds an `AlertDialog` may not also construct a
/// `TextEditingController` (see `test/features/text_prompt_guard_test.dart`).
/// A form screen legitimately owns controllers — a form is not a dialog, and its
/// controllers die with the route — so a screen that both *edits text* and needs
/// to *ask something* has to put the asking somewhere else. That somewhere is
/// here.
///
/// Deliberately not a text prompt. A confirmation takes no input, so it has
/// nothing to get wrong about controller lifetime, which is the entire reason
/// `TextPromptDialog` had to exist.
Future<bool> confirmYesNo(
  BuildContext context, {
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        destructive
            ? FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel),
              )
            : FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel),
              ),
      ],
    ),
  );
  return answer ?? false;
}
