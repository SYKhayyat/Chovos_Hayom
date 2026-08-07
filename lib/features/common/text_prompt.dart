import 'package:flutter/material.dart';

/// A prompt that **owns its controllers**.
///
/// The obvious way to write this is to make a `TextEditingController` beside the
/// `showDialog` call and dispose it as soon as the await returns — often in a
/// tidy-looking `try`/`finally`. That is wrong, and quietly: `showDialog`'s
/// future completes when the route is *popped*, not when it is gone, and the
/// exit animation still has frames to render against a `TextField` that is still
/// holding the controller. The next frame throws
///
///     A TextEditingController was used after being disposed.
///
/// Four dialogs in this app had that shape (renaming a profile, the chazara
/// intervals, the backup interval, and the clipboard import) and a fifth was
/// caught by a test while it was being written. So the controllers live here,
/// on a `State`, and die exactly when the widgets using them do.
///
/// **Two more dialogs hand-rolled it anyway**, and the reason they did is the
/// interesting part: both wanted *two* fields, and this class took one. So the
/// add/rename-a-meforish dialog and the finish-a-range dialog each grew their
/// own `State`, their own pair of controllers and their own `dispose` — each
/// carrying a paragraph explaining the bug above, which is three copies of one
/// piece of knowledge and two chances to get it wrong. The range dialog wanted a
/// second thing this could not do as well: **reject its own input and stay
/// open**, which is why it also owned an error string.
///
/// It takes a list of fields and an optional validator now. There is nothing
/// left for a caller to hand-roll, which is the only kind of "don't hand-roll
/// this" that holds.
///
/// Use [promptForText] (one field) or [promptForFields] rather than this class
/// directly.

/// One field of a prompt.
class PromptField {
  const PromptField({
    required this.key,
    this.label,
    this.hintText,
    this.initialValue = '',
    this.keyboardType,
    this.maxLines = 1,
    this.textDirection,
    this.trim = true,
  });

  /// How the value is named in the returned map.
  final String key;

  final String? label;
  final String? hintText;
  final String initialValue;
  final TextInputType? keyboardType;
  final int maxLines;

  /// Forced direction, for a field whose content is a known script — the Hebrew
  /// half of a name pair reads right-to-left whatever locale the app is in.
  final TextDirection? textDirection;

  /// Whether to trim this field's value. On for everything that is a name or a
  /// number; the caller that parses a comma-separated list trims the parts
  /// itself, so it makes no difference to it either.
  final bool trim;
}

/// How a prompt's fields are laid out.
enum PromptLayout {
  /// One under another. Right for anything with a label worth reading.
  column,

  /// Side by side. Right for a pair of short numbers that are one answer — a
  /// *from* and a *to* stacked read as two questions.
  row,
}

class TextPromptDialog extends StatefulWidget {
  const TextPromptDialog({
    super.key,
    required this.title,
    required this.fields,
    required this.confirmLabel,
    required this.cancelLabel,
    this.body,
    this.footer,
    this.validate,
    this.layout = PromptLayout.column,
  });

  final String title;
  final List<PromptField> fields;
  final String confirmLabel;
  final String cancelLabel;

  /// Optional explanation shown above the fields.
  final String? body;

  /// Optional note shown below them — the "either name is enough" line.
  final String? footer;

  /// Returns a message to show *and keep the dialog open*, or null to accept.
  ///
  /// Rejecting has to happen here rather than after the await: a dialog that
  /// closes and then complains has thrown away what the user typed, and on a
  /// keypad phone re-entering two numbers is a dozen key presses.
  final String? Function(Map<String, String> values)? validate;

  final PromptLayout layout;

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  late final Map<String, TextEditingController> _controllers = {
    for (final f in widget.fields)
      f.key: TextEditingController(text: f.initialValue),
  };
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> get _values => {
        for (final f in widget.fields)
          f.key: f.trim
              ? _controllers[f.key]!.text.trim()
              : _controllers[f.key]!.text,
      };

  void _submit() {
    final values = _values;
    final error = widget.validate?.call(values);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, values);
  }

  /// The last single-line field: pressing Enter there submits. On a multi-line
  /// field Enter is a newline, so there is nothing to attach.
  String? get _submittingField {
    for (final f in widget.fields.reversed) {
      if (f.maxLines == 1) return f.key;
    }
    return null;
  }

  Widget _field(PromptField f, {required bool autofocus}) => TextField(
        controller: _controllers[f.key],
        autofocus: autofocus,
        keyboardType: f.keyboardType,
        maxLines: f.maxLines,
        textDirection: f.textDirection,
        decoration: InputDecoration(labelText: f.label, hintText: f.hintText),
        onSubmitted: f.key == _submittingField ? (_) => _submit() : null,
      );

  @override
  Widget build(BuildContext context) {
    final fields = [
      for (var i = 0; i < widget.fields.length; i++)
        _field(widget.fields[i], autofocus: i == 0),
    ];

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.body != null) ...[
            Text(widget.body!),
            const SizedBox(height: 8),
          ],
          if (widget.layout == PromptLayout.row)
            Row(
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: fields[i]),
                ],
              ],
            )
          else
            ...fields,
          if (widget.footer != null) ...[
            const SizedBox(height: 8),
            Text(widget.footer!,
                style: Theme.of(context).textTheme.bodySmall),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.cancelLabel)),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// Ask for several values at once. Returns null if it was dismissed.
Future<Map<String, String>?> promptForFields(
  BuildContext context, {
  required String title,
  required List<PromptField> fields,
  required String confirmLabel,
  required String cancelLabel,
  String? body,
  String? footer,
  String? Function(Map<String, String> values)? validate,
  PromptLayout layout = PromptLayout.column,
}) =>
    showDialog<Map<String, String>>(
      context: context,
      builder: (_) => TextPromptDialog(
        title: title,
        fields: fields,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        body: body,
        footer: footer,
        validate: validate,
        layout: layout,
      ),
    );

/// Ask for one line (or block) of text. Returns null if it was dismissed, which
/// every caller distinguishes from an empty string.
Future<String?> promptForText(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required String cancelLabel,
  String? body,
  String? label,
  String? hintText,
  String initialValue = '',
  TextInputType? keyboardType,
  int maxLines = 1,
  bool trim = true,

  /// Returns a message to show *and keep the dialog open*. See
  /// [TextPromptDialog.validate] — a prompt that closes before it complains has
  /// thrown away what the user typed.
  String? Function(String value)? validate,
}) async {
  final values = await promptForFields(
    context,
    title: title,
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
    body: body,
    validate: validate == null ? null : (v) => validate(v['text']!),
    fields: [
      PromptField(
        key: 'text',
        label: label,
        hintText: hintText,
        initialValue: initialValue,
        keyboardType: keyboardType,
        maxLines: maxLines,
        trim: trim,
      ),
    ],
  );
  return values?['text'];
}
