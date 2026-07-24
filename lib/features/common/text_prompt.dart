import 'package:flutter/material.dart';

/// A one-field text prompt that **owns its controller**.
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
/// caught by a test while it was being written. So the controller lives here,
/// on a `State`, and dies exactly when the widgets using it do.
///
/// Use [promptForText] rather than this class directly.
class TextPromptDialog extends StatefulWidget {
  const TextPromptDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    required this.cancelLabel,
    this.body,
    this.label,
    this.hintText,
    this.initialValue = '',
    this.keyboardType,
    this.maxLines = 1,
    this.trim = true,
  });

  final String title;
  final String confirmLabel;
  final String cancelLabel;

  /// Optional explanation shown above the field.
  final String? body;

  final String? label;
  final String? hintText;
  final String initialValue;
  final TextInputType? keyboardType;
  final int maxLines;

  /// Whether to trim the returned value. On for everything that is a name or a
  /// number; the callers that parse a comma-separated list trim the parts
  /// themselves, so it makes no difference to them either.
  final bool trim;

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(
      context, widget.trim ? _controller.text.trim() : _controller.text);

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: _controller,
      autofocus: true,
      keyboardType: widget.keyboardType,
      maxLines: widget.maxLines,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
      ),
      // Only a single-line field can meaningfully be "submitted"; on a
      // multi-line one Enter is a newline.
      onSubmitted: widget.maxLines == 1 ? (_) => _submit() : null,
    );

    return AlertDialog(
      title: Text(widget.title),
      content: widget.body == null
          ? field
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.body!),
                const SizedBox(height: 8),
                field,
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
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => TextPromptDialog(
        title: title,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        body: body,
        label: label,
        hintText: hintText,
        initialValue: initialValue,
        keyboardType: keyboardType,
        maxLines: maxLines,
        trim: trim,
      ),
    );
