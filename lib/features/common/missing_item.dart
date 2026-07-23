import 'package:flutter/material.dart';

/// What a screen shows when the id in its route doesn't resolve.
///
/// Routes carry ids rather than objects, which means every id-addressed screen
/// has two states its predecessors never had: the catalog is still loading (a
/// cold start from a deep link or a restored stack), and the id is genuinely
/// gone (hidden, deleted, or from a link written before it was). Spinning
/// forever on the second is the failure worth avoiding, so [loading] separates
/// them explicitly rather than being inferred from a null.
class MissingItemScreen extends StatelessWidget {
  const MissingItemScreen({
    super.key,
    required this.loading,
    required this.message,
    this.title = '',
  });

  /// True while the data that would resolve the id is still on its way.
  final bool loading;

  /// What to say once it is clear the id will never resolve.
  final String message;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: loading
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
      ),
    );
  }
}
