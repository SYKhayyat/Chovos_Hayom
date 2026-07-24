import 'dart:convert';

import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/usecases/layer_requirements.dart';
import 'package:chovos_hayom/features/settings/settings_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/in_memory_progress_repository.dart';

/// A backup has to contain everything, including the parts no screen happens to
/// be looking at.
///
/// The export used to read its four repository-backed lists off their providers
/// as `.asData?.value ?? const []`. Nothing on the Settings screen keeps
/// `customNodesProvider` alive, so that fallback is not hypothetical: the export
/// would quietly omit every custom sefer, custom meforish and required/offered
/// set, and then say "Exported to clipboard". A backup you only find out is
/// incomplete when you restore it is the worst kind there is.
void main() {
  testWidgets('exporting carries the custom sefarim, mefarshim and layer config',
      (tester) async {
    final repo = InMemoryProgressRepository();
    const profile = 'default';
    await repo.addCustomNode(
      profile,
      const CatalogNode(
        id: 'mine',
        parentId: null,
        name: 'My sefer',
        kind: NodeKind.leaf,
        unitLabel: UnitLabel.perek,
        unitCount: 5,
        unitOffset: 1,
      ),
    );
    await repo.addCustomLayer(
        profile, const Layer(id: 'maharsha', name: 'Maharsha'));
    await repo.setLayerRequirement(
      profile,
      const LayerConfigEntry(
          nodeId: 'shas', unitIndex: -1, layers: {mainLayerId, 'maharsha'}),
    );
    await repo.setOfferedLayers(
      profile,
      const LayerConfigEntry(
          nodeId: 'shas', unitIndex: -1, layers: {mainLayerId, 'maharsha'}),
    );

    // Capture what the app puts on the clipboard.
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = ((call.arguments as Map)['text'] as String?);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        progressRepositoryProvider.overrideWithValue(repo),
        appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
      ],
      child: localizedApp(home: const SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Export to clipboard'), 200);
    // scrollUntilVisible stops the moment the target is attached, which can
    // leave it flush against the viewport edge where a tap misses it.
    await tester.ensureVisible(find.text('Export to clipboard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export to clipboard'));
    await tester.pumpAndSettle();

    expect(find.text('Exported to clipboard'), findsOneWidget);
    final backup = jsonDecode(copied!) as Map<String, dynamic>;
    expect((backup['customNodes'] as List), hasLength(1));
    expect((backup['customLayers'] as List), hasLength(1));
    expect((backup['requirements'] as List), hasLength(1));
    expect((backup['offered'] as List), hasLength(1));
  });
}
