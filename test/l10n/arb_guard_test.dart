import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The rules this file enforces about the `.arb` files themselves — the ones
/// `gen-l10n` has no opinion about, and the untranslated-locale gate cannot see.
///
/// That gate answers exactly one question: is every key in the template also in
/// `app_he.arb`? It is a good question and it is not the only one. Two failures
/// slip past it in opposite directions:
///
/// * **A key nobody reads.** Five of them had accumulated —
///   `addNodeHebrewName`, `addNodeNeedName`, `errorTitle`,
///   `mefarshimHebrewOptional` and `dateTimeLabel` — every one of them written,
///   described, translated into Hebrew, and called from nowhere. Four were the
///   leftovers of a de-duplication that reached the call sites and not the
///   string table; `dateTimeLabel` was the opposite and worse, a key that
///   existed *because* a screen needed it while the screen glued the string by
///   hand instead. A dead key costs a translator real work and reads, to anyone
///   auditing the table, as a string that ships.
///
/// * **A key translated to itself.** `cycleDafHebrew` was `"{sefer} · דף
///   {unit}"` in `app_en.arb` and the identical string in `app_he.arb`. Present
///   in both files, so the gate called it translated; identical in both, so it
///   was not a translation at all but one Hebrew literal stored twice, where a
///   translator changing one copy would have made the same line render
///   differently in the two locales with nothing to notice.
///
/// * **A metadata block whose message has been renamed.** `goalBanner` became
///   `goalStatus` when the unit grid's banner and the Goals row stopped writing
///   the same sentence twice, and the rename reached the message and not the
///   `@goalBanner` block beside it. Nothing failed: gen-l10n does not require
///   metadata, so the orphan block was ignored and the three placeholders it
///   declared as `String` were re-inferred as **`Object`**. The signature
///   `goalStatus(Object, Object, Object)` accepts the `double` that
///   `requiredPerDay` is, and renders `2.4285714285714284` into a sentence the
///   `String` version would not have compiled. A declaration that has come
///   loose from its message is worse than no declaration, because the table
///   still reads as though the types are stated.
///
/// **The naive version of the second rule is wrong, and worth saying so here so
/// nobody "fixes" it into existence.** "No Hebrew in the English template"
/// would reject `settingsLanguage` (`"Hebrew (עברית)"` — a language named in its
/// own script, which is what every language picker does), and `siyumEmpty` and
/// `siyumCount`, which end English sentences in `חזק!` and `יישר כח!` because
/// that is how the people who use this app end them. All three are *English
/// strings*, translated to different Hebrew ones. The defect is not the script.
/// It is a template entry and its translation being the same bytes.
void main() {
  Map<String, dynamic> arb(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;

  /// `@key` blocks are metadata and `@@locale` is a header; neither ships.
  bool isMessage(String key) => !key.startsWith('@');

  /// A message with its placeholders removed, so `"{node} · {unit}"` — which is
  /// genuinely locale-independent and genuinely identical in both files — is not
  /// mistaken for an untranslated string. Innermost-first and repeated, because
  /// an ICU plural nests: `{count, plural, =1{…} other{{count} …}}`.
  String withoutPlaceholders(String value) {
    final braces = RegExp(r'\{[^{}]*\}');
    var out = value;
    while (braces.hasMatch(out)) {
      out = out.replaceAll(braces, '');
    }
    return out;
  }

  final letter = RegExp(r'\p{L}', unicode: true);

  /// Every line of hand-written `lib/`, concatenated. The generated table is
  /// excluded for the obvious reason: it mentions every key by definition, so
  /// scanning it would make the dead-key rule vacuously true.
  String appSource() {
    final buffer = StringBuffer();
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.contains('/l10n/generated/') || path.endsWith('.g.dart')) {
        continue;
      }
      buffer.writeln(entity.readAsStringSync());
    }
    return buffer.toString();
  }

  /// Call sites are `l10n.someKey` or `AppLocalizations.of(context).someKey`;
  /// both are a dot, the key, and a boundary. Nothing in this app reaches a
  /// message any other way — there is no lookup by string, which is the one
  /// thing that would make this rule unsound.
  bool isCalled(String key, String source) =>
      RegExp(r'\.' + key + r'\b').hasMatch(source);

  test('the call-site matcher matches a call site and not a coincidence', () {
    // A guard that scans source is only as good as its regex, and a regex that
    // has quietly stopped matching passes every time. So: prove it can see one,
    // and prove it is not fooled by the key appearing as a longer identifier or
    // as a bare word.
    expect(isCalled('logSheetPickDate', 'Text(l10n.logSheetPickDate),'), isTrue);
    expect(
        isCalled('appTitle', 'AppLocalizations.of(context).appTitle'), isTrue);
    expect(isCalled('errorTitle', 'final errorTitle = 3;'), isFalse);
    expect(isCalled('errorTitle', 'l10n.errorTitleBanner'), isFalse);
  });

  test('the placeholder stripper leaves the words and takes the slots', () {
    expect(withoutPlaceholders('{node} · {unit}').trim(), '·');
    expect(withoutPlaceholders('{sefer} · דף {unit}'), contains('דף'));
    expect(
        withoutPlaceholders('{count, plural, =1{1 siyum} other{{count} x}} — y!')
            .trim(),
        '— y!');
  });

  test('every message in the template is read by something in lib/', () {
    final source = appSource();
    final dead = [
      for (final key in arb('en').keys.where(isMessage))
        if (!isCalled(key, source)) key,
    ];

    expect(dead, isEmpty,
        reason: 'these keys are translated and never displayed. Delete them, '
            'or find the screen that is building the string by hand instead — '
            'which is how `dateTimeLabel` came to exist unused while '
            'log_unit_sheet.dart formatted a date and a time itself, in the '
            'one place in the app where the Hebrew calendar setting was '
            'ignored.');
  });

  test('no message is its own translation', () {
    final en = arb('en');
    final he = arb('he');

    final identical = [
      for (final key in en.keys.where(isMessage))
        if (he[key] == en[key] &&
            letter.hasMatch(withoutPlaceholders(en[key] as String)))
          '$key = ${en[key]}',
    ];

    expect(identical, isEmpty,
        reason: 'these entries are byte-identical in both locales and contain '
            'words, so one of two things is true: the Hebrew is a copy nobody '
            'translated (which the untranslated-locale gate cannot see, since '
            'the key *is* present), or the string is locale-independent and '
            'does not belong in a translated table at all. The second case is '
            'what `cycleDafHebrew` was; it is now composed from `app_he.arb`\'s '
            'own `unitLabelDaf` in features/common/naming.dart.');
  });

  /// The placeholder names a message actually interpolates: `{name}` and the
  /// `{count, plural, …}` head alike, since both are arguments to the generated
  /// method. Nested placeholders inside a plural's arms name the same argument
  /// as the head, so a set is the right shape.
  Set<String> placeholdersIn(String value) => {
        for (final m in RegExp(r'\{\s*(\w+)\s*[,}]').allMatches(value))
          m.group(1)!,
      };

  /// What `@key` declares, or the empty set when there is no block.
  Set<String> declaredFor(String key, Map<String, dynamic> arb) {
    final meta = arb['@$key'];
    if (meta is! Map || meta['placeholders'] is! Map) return const {};
    return {for (final k in (meta['placeholders'] as Map).keys) '$k'};
  }

  test('the placeholder reader sees both shapes and invents nothing', () {
    expect(placeholdersIn('By {date} · need {rate}/day · {status}'),
        {'date', 'rate', 'status'});
    expect(placeholdersIn('{count, plural, =1{1 goal} other{{count} goals}}'),
        {'count'});
    expect(placeholdersIn('Nothing to interpolate here'), isEmpty);
  });

  test('every @metadata block belongs to a message that exists', () {
    final en = arb('en');
    final orphans = [
      for (final key in en.keys)
        // `@@locale` is a header and `@_SECTION` blocks are the table's own
        // dividers; neither describes a message.
        if (key.startsWith('@') &&
            !key.startsWith('@@') &&
            !key.startsWith('@_') &&
            !en.containsKey(key.substring(1)))
          key,
    ];

    expect(orphans, isEmpty,
        reason: 'these blocks describe messages that are not in the table, so '
            'they declare nothing and the message they were written for — if '
            'it was renamed rather than deleted — now has its placeholders '
            'inferred as Object. That is how `@goalBanner` outlived '
            '`goalBanner`.');
  });

  test('every placeholder a message uses is declared with a type', () {
    final en = arb('en');
    final undeclared = [
      for (final key in en.keys.where(isMessage))
        for (final name in placeholdersIn(en[key] as String))
          if (!declaredFor(key, en).contains(name)) '$key ← {$name}',
    ];

    expect(undeclared, isEmpty,
        reason: 'gen-l10n types an undeclared placeholder as `Object`, so the '
            'generated method accepts anything and interpolates its '
            '`toString()`. The declaration is the only thing that makes '
            '`String date` mean a date somebody has already formatted.\n\n'
            '${undeclared.join('\n')}');
  });

  test('the two rules fail on a violation, rather than only passing', () {
    // The negative controls. Both rules are "look through a list and find
    // nothing", which is the assertion shape that passes when the list is empty
    // for the wrong reason — an .arb that failed to parse, a scan that matched
    // no files. Hand each one the defect it was written for.
    expect(isCalled('aKeyNobodyCalls', appSource()), isFalse,
        reason: 'a key that genuinely has no call site must not be found');

    const same = 'שבת · דף 12';
    expect(letter.hasMatch(withoutPlaceholders(same)), isTrue,
        reason: 'the identical-value rule must see Hebrew script as words');
    const pureTemplate = '{node} · {unit}';
    expect(letter.hasMatch(withoutPlaceholders(pureTemplate)), isFalse,
        reason: 'and must not see a bare placeholder template as words, or '
            'every separator in the table becomes a violation');

    // And the same for the two rules above, fed the exact table that produced
    // them: a block left behind by a rename, and the message it stopped
    // describing.
    const rotted = <String, dynamic>{
      'goalStatus': 'By {date} · need {rate}/day',
      '@goalBanner': {
        'placeholders': {
          'date': {'type': 'String'},
          'rate': {'type': 'String'},
        },
      },
    };
    expect(rotted.containsKey('goalBanner'), isFalse,
        reason: 'the orphan rule must find a block whose message is gone');
    expect(declaredFor('goalStatus', rotted), isEmpty,
        reason: 'and the placeholder rule must read the orphaned block as '
            'declaring nothing for the message that is actually there');
    expect(placeholdersIn(rotted['goalStatus'] as String), {'date', 'rate'});
  });
}
