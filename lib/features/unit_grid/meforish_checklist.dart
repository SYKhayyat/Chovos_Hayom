import 'package:flutter/material.dart';

import '../../domain/entities/layer.dart';
import '../../domain/usecases/unit_mefarshim.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/naming.dart';

/// The list of tickable mefarshim, drawn once.
///
/// Two sheets show it and they mean different things by a tick — the per-unit
/// checklist *writes* on every change, the log sheet collects a selection to
/// submit at the end — so the state stays with the caller and only the rows are
/// shared. What was worth sharing is what the two had already drifted apart on:
/// the row's density, whether a name that no longer resolves reads as
/// *Deleted meforish* or as a raw UUID, and whether the row says what the
/// meforish *is* on this unit.
///
/// [showRole] is the one real difference between the two call sites and it is a
/// real one: on the checklist "Required / Optional" is the answer to *why is
/// this unit not finished*, and on the log sheet — where you are choosing what
/// you just learned — it is noise.
class MeforishChecklist extends StatelessWidget {
  const MeforishChecklist({
    super.key,
    required this.mefarshim,
    required this.layers,
    required this.isChecked,
    required this.onChanged,
    this.showRole = false,
  });

  /// The rows, in order. See [UnitMefarshim].
  final List<UnitMeforish> mefarshim;

  /// Every meforish the app knows about, for resolving an id to a name. An id
  /// with nothing behind it is one whose meforish was deleted after this unit
  /// was marked; [layerById] names it rather than printing the UUID.
  final List<Layer> layers;

  final bool Function(String layerId) isChecked;
  final void Function(String layerId, bool checked) onChanged;
  final bool showRole;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final m in mefarshim)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: isChecked(m.layerId),
            title: Text(layerNameById(l10n, layers, m.layerId)),
            subtitle: !showRole
                ? null
                : Text(m.isRequired ? l10n.labelRequired : l10n.labelOptional),
            onChanged: (v) => onChanged(m.layerId, v == true),
          ),
      ],
    );
  }
}
