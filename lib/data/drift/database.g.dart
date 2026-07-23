// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ProfilesTable extends Profiles
    with TableInfo<$ProfilesTable, ProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _settingsJsonMeta = const VerificationMeta(
    'settingsJson',
  );
  @override
  late final GeneratedColumn<String> settingsJson = GeneratedColumn<String>(
    'settings_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt, settingsJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('settings_json')) {
      context.handle(
        _settingsJsonMeta,
        settingsJson.isAcceptableOrUnknown(
          data['settings_json']!,
          _settingsJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      settingsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}settings_json'],
      )!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class ProfileRow extends DataClass implements Insertable<ProfileRow> {
  final String id;
  final String name;
  final DateTime createdAt;
  final String settingsJson;
  const ProfileRow({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.settingsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['settings_json'] = Variable<String>(settingsJson);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      settingsJson: Value(settingsJson),
    );
  }

  factory ProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      settingsJson: serializer.fromJson<String>(json['settingsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'settingsJson': serializer.toJson<String>(settingsJson),
    };
  }

  ProfileRow copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    String? settingsJson,
  }) => ProfileRow(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    settingsJson: settingsJson ?? this.settingsJson,
  );
  ProfileRow copyWithCompanion(ProfilesCompanion data) {
    return ProfileRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      settingsJson: data.settingsJson.present
          ? data.settingsJson.value
          : this.settingsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('settingsJson: $settingsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt, settingsJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.settingsJson == this.settingsJson);
}

class ProfilesCompanion extends UpdateCompanion<ProfileRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<String> settingsJson;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.settingsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String id,
    required String name,
    required DateTime createdAt,
    this.settingsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<ProfileRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<String>? settingsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (settingsJson != null) 'settings_json': settingsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
    Value<String>? settingsJson,
    Value<int>? rowid,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      settingsJson: settingsJson ?? this.settingsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (settingsJson.present) {
      map['settings_json'] = Variable<String>(settingsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('settingsJson: $settingsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LearningEventsTable extends LearningEvents
    with TableInfo<$LearningEventsTable, LearningEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nodeIdMeta = const VerificationMeta('nodeId');
  @override
  late final GeneratedColumn<String> nodeId = GeneratedColumn<String>(
    'node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitIndexMeta = const VerificationMeta(
    'unitIndex',
  );
  @override
  late final GeneratedColumn<int> unitIndex = GeneratedColumn<int>(
    'unit_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<EventAction, int> action =
      GeneratedColumn<int>(
        'action',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<EventAction>($LearningEventsTable.$converteraction);
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _loggedAtMeta = const VerificationMeta(
    'loggedAt',
  );
  @override
  late final GeneratedColumn<DateTime> loggedAt = GeneratedColumn<DateTime>(
    'logged_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMinMeta = const VerificationMeta(
    'durationMin',
  );
  @override
  late final GeneratedColumn<int> durationMin = GeneratedColumn<int>(
    'duration_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _layersJsonMeta = const VerificationMeta(
    'layersJson',
  );
  @override
  late final GeneratedColumn<String> layersJson = GeneratedColumn<String>(
    'layers_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    nodeId,
    unitIndex,
    action,
    occurredAt,
    loggedAt,
    durationMin,
    note,
    layersJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('node_id')) {
      context.handle(
        _nodeIdMeta,
        nodeId.isAcceptableOrUnknown(data['node_id']!, _nodeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_nodeIdMeta);
    }
    if (data.containsKey('unit_index')) {
      context.handle(
        _unitIndexMeta,
        unitIndex.isAcceptableOrUnknown(data['unit_index']!, _unitIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_unitIndexMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('logged_at')) {
      context.handle(
        _loggedAtMeta,
        loggedAt.isAcceptableOrUnknown(data['logged_at']!, _loggedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_loggedAtMeta);
    }
    if (data.containsKey('duration_min')) {
      context.handle(
        _durationMinMeta,
        durationMin.isAcceptableOrUnknown(
          data['duration_min']!,
          _durationMinMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('layers_json')) {
      context.handle(
        _layersJsonMeta,
        layersJson.isAcceptableOrUnknown(data['layers_json']!, _layersJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LearningEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      nodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}node_id'],
      )!,
      unitIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_index'],
      )!,
      action: $LearningEventsTable.$converteraction.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}action'],
        )!,
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      loggedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}logged_at'],
      )!,
      durationMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_min'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      layersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layers_json'],
      ),
    );
  }

  @override
  $LearningEventsTable createAlias(String alias) {
    return $LearningEventsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<EventAction, int, int> $converteraction =
      const EnumIndexConverter<EventAction>(EventAction.values);
}

class LearningEventRow extends DataClass
    implements Insertable<LearningEventRow> {
  final String id;
  final String profileId;
  final String nodeId;
  final int unitIndex;
  final EventAction action;
  final DateTime occurredAt;
  final DateTime loggedAt;
  final int? durationMin;

  /// A **haara** — the single free-text field on an event: an insight on the daf,
  /// a question, how the seder went, whatever you want to keep. Every non-empty
  /// one shows up in the Notes Journal. (Until v8 this was split into `note` and
  /// a separate `haara`; the v7 -> v8 migration folds the two together here.)
  final String? note;

  /// JSON list of layer ids this event marks/unmarks (the text and/or mefarshim).
  /// Null is read as `["main"]` — the primary text — matching pre-layers events.
  final String? layersJson;
  const LearningEventRow({
    required this.id,
    required this.profileId,
    required this.nodeId,
    required this.unitIndex,
    required this.action,
    required this.occurredAt,
    required this.loggedAt,
    this.durationMin,
    this.note,
    this.layersJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['node_id'] = Variable<String>(nodeId);
    map['unit_index'] = Variable<int>(unitIndex);
    {
      map['action'] = Variable<int>(
        $LearningEventsTable.$converteraction.toSql(action),
      );
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['logged_at'] = Variable<DateTime>(loggedAt);
    if (!nullToAbsent || durationMin != null) {
      map['duration_min'] = Variable<int>(durationMin);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || layersJson != null) {
      map['layers_json'] = Variable<String>(layersJson);
    }
    return map;
  }

  LearningEventsCompanion toCompanion(bool nullToAbsent) {
    return LearningEventsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      nodeId: Value(nodeId),
      unitIndex: Value(unitIndex),
      action: Value(action),
      occurredAt: Value(occurredAt),
      loggedAt: Value(loggedAt),
      durationMin: durationMin == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMin),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      layersJson: layersJson == null && nullToAbsent
          ? const Value.absent()
          : Value(layersJson),
    );
  }

  factory LearningEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningEventRow(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      nodeId: serializer.fromJson<String>(json['nodeId']),
      unitIndex: serializer.fromJson<int>(json['unitIndex']),
      action: $LearningEventsTable.$converteraction.fromJson(
        serializer.fromJson<int>(json['action']),
      ),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      loggedAt: serializer.fromJson<DateTime>(json['loggedAt']),
      durationMin: serializer.fromJson<int?>(json['durationMin']),
      note: serializer.fromJson<String?>(json['note']),
      layersJson: serializer.fromJson<String?>(json['layersJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String>(profileId),
      'nodeId': serializer.toJson<String>(nodeId),
      'unitIndex': serializer.toJson<int>(unitIndex),
      'action': serializer.toJson<int>(
        $LearningEventsTable.$converteraction.toJson(action),
      ),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'loggedAt': serializer.toJson<DateTime>(loggedAt),
      'durationMin': serializer.toJson<int?>(durationMin),
      'note': serializer.toJson<String?>(note),
      'layersJson': serializer.toJson<String?>(layersJson),
    };
  }

  LearningEventRow copyWith({
    String? id,
    String? profileId,
    String? nodeId,
    int? unitIndex,
    EventAction? action,
    DateTime? occurredAt,
    DateTime? loggedAt,
    Value<int?> durationMin = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<String?> layersJson = const Value.absent(),
  }) => LearningEventRow(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    nodeId: nodeId ?? this.nodeId,
    unitIndex: unitIndex ?? this.unitIndex,
    action: action ?? this.action,
    occurredAt: occurredAt ?? this.occurredAt,
    loggedAt: loggedAt ?? this.loggedAt,
    durationMin: durationMin.present ? durationMin.value : this.durationMin,
    note: note.present ? note.value : this.note,
    layersJson: layersJson.present ? layersJson.value : this.layersJson,
  );
  LearningEventRow copyWithCompanion(LearningEventsCompanion data) {
    return LearningEventRow(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      nodeId: data.nodeId.present ? data.nodeId.value : this.nodeId,
      unitIndex: data.unitIndex.present ? data.unitIndex.value : this.unitIndex,
      action: data.action.present ? data.action.value : this.action,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      loggedAt: data.loggedAt.present ? data.loggedAt.value : this.loggedAt,
      durationMin: data.durationMin.present
          ? data.durationMin.value
          : this.durationMin,
      note: data.note.present ? data.note.value : this.note,
      layersJson: data.layersJson.present
          ? data.layersJson.value
          : this.layersJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningEventRow(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('nodeId: $nodeId, ')
          ..write('unitIndex: $unitIndex, ')
          ..write('action: $action, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('durationMin: $durationMin, ')
          ..write('note: $note, ')
          ..write('layersJson: $layersJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    nodeId,
    unitIndex,
    action,
    occurredAt,
    loggedAt,
    durationMin,
    note,
    layersJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningEventRow &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.nodeId == this.nodeId &&
          other.unitIndex == this.unitIndex &&
          other.action == this.action &&
          other.occurredAt == this.occurredAt &&
          other.loggedAt == this.loggedAt &&
          other.durationMin == this.durationMin &&
          other.note == this.note &&
          other.layersJson == this.layersJson);
}

class LearningEventsCompanion extends UpdateCompanion<LearningEventRow> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<String> nodeId;
  final Value<int> unitIndex;
  final Value<EventAction> action;
  final Value<DateTime> occurredAt;
  final Value<DateTime> loggedAt;
  final Value<int?> durationMin;
  final Value<String?> note;
  final Value<String?> layersJson;
  final Value<int> rowid;
  const LearningEventsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.nodeId = const Value.absent(),
    this.unitIndex = const Value.absent(),
    this.action = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.loggedAt = const Value.absent(),
    this.durationMin = const Value.absent(),
    this.note = const Value.absent(),
    this.layersJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LearningEventsCompanion.insert({
    required String id,
    required String profileId,
    required String nodeId,
    required int unitIndex,
    required EventAction action,
    required DateTime occurredAt,
    required DateTime loggedAt,
    this.durationMin = const Value.absent(),
    this.note = const Value.absent(),
    this.layersJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       profileId = Value(profileId),
       nodeId = Value(nodeId),
       unitIndex = Value(unitIndex),
       action = Value(action),
       occurredAt = Value(occurredAt),
       loggedAt = Value(loggedAt);
  static Insertable<LearningEventRow> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<String>? nodeId,
    Expression<int>? unitIndex,
    Expression<int>? action,
    Expression<DateTime>? occurredAt,
    Expression<DateTime>? loggedAt,
    Expression<int>? durationMin,
    Expression<String>? note,
    Expression<String>? layersJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (nodeId != null) 'node_id': nodeId,
      if (unitIndex != null) 'unit_index': unitIndex,
      if (action != null) 'action': action,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (loggedAt != null) 'logged_at': loggedAt,
      if (durationMin != null) 'duration_min': durationMin,
      if (note != null) 'note': note,
      if (layersJson != null) 'layers_json': layersJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LearningEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? profileId,
    Value<String>? nodeId,
    Value<int>? unitIndex,
    Value<EventAction>? action,
    Value<DateTime>? occurredAt,
    Value<DateTime>? loggedAt,
    Value<int?>? durationMin,
    Value<String?>? note,
    Value<String?>? layersJson,
    Value<int>? rowid,
  }) {
    return LearningEventsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      nodeId: nodeId ?? this.nodeId,
      unitIndex: unitIndex ?? this.unitIndex,
      action: action ?? this.action,
      occurredAt: occurredAt ?? this.occurredAt,
      loggedAt: loggedAt ?? this.loggedAt,
      durationMin: durationMin ?? this.durationMin,
      note: note ?? this.note,
      layersJson: layersJson ?? this.layersJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (nodeId.present) {
      map['node_id'] = Variable<String>(nodeId.value);
    }
    if (unitIndex.present) {
      map['unit_index'] = Variable<int>(unitIndex.value);
    }
    if (action.present) {
      map['action'] = Variable<int>(
        $LearningEventsTable.$converteraction.toSql(action.value),
      );
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (loggedAt.present) {
      map['logged_at'] = Variable<DateTime>(loggedAt.value);
    }
    if (durationMin.present) {
      map['duration_min'] = Variable<int>(durationMin.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (layersJson.present) {
      map['layers_json'] = Variable<String>(layersJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningEventsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('nodeId: $nodeId, ')
          ..write('unitIndex: $unitIndex, ')
          ..write('action: $action, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('durationMin: $durationMin, ')
          ..write('note: $note, ')
          ..write('layersJson: $layersJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CustomNodesTable extends CustomNodes
    with TableInfo<$CustomNodesTable, CustomNodeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomNodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameHebrewMeta = const VerificationMeta(
    'nameHebrew',
  );
  @override
  late final GeneratedColumn<String> nameHebrew = GeneratedColumn<String>(
    'name_hebrew',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<NodeKind, int> kind =
      GeneratedColumn<int>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<NodeKind>($CustomNodesTable.$converterkind);
  @override
  late final GeneratedColumnWithTypeConverter<UnitLabel?, int> unitLabel =
      GeneratedColumn<int>(
        'unit_label',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<UnitLabel?>($CustomNodesTable.$converterunitLabeln);
  static const VerificationMeta _unitCountMeta = const VerificationMeta(
    'unitCount',
  );
  @override
  late final GeneratedColumn<int> unitCount = GeneratedColumn<int>(
    'unit_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _unitOffsetMeta = const VerificationMeta(
    'unitOffset',
  );
  @override
  late final GeneratedColumn<int> unitOffset = GeneratedColumn<int>(
    'unit_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _unitNamesJsonMeta = const VerificationMeta(
    'unitNamesJson',
  );
  @override
  late final GeneratedColumn<String> unitNamesJson = GeneratedColumn<String>(
    'unit_names_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    parentId,
    name,
    nameHebrew,
    sortOrder,
    kind,
    unitLabel,
    unitCount,
    unitOffset,
    hidden,
    unitNamesJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'custom_nodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<CustomNodeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('name_hebrew')) {
      context.handle(
        _nameHebrewMeta,
        nameHebrew.isAcceptableOrUnknown(data['name_hebrew']!, _nameHebrewMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('unit_count')) {
      context.handle(
        _unitCountMeta,
        unitCount.isAcceptableOrUnknown(data['unit_count']!, _unitCountMeta),
      );
    }
    if (data.containsKey('unit_offset')) {
      context.handle(
        _unitOffsetMeta,
        unitOffset.isAcceptableOrUnknown(data['unit_offset']!, _unitOffsetMeta),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    if (data.containsKey('unit_names_json')) {
      context.handle(
        _unitNamesJsonMeta,
        unitNamesJson.isAcceptableOrUnknown(
          data['unit_names_json']!,
          _unitNamesJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, id};
  @override
  CustomNodeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomNodeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nameHebrew: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_hebrew'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      kind: $CustomNodesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}kind'],
        )!,
      ),
      unitLabel: $CustomNodesTable.$converterunitLabeln.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}unit_label'],
        ),
      ),
      unitCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_count'],
      )!,
      unitOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_offset'],
      )!,
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
      unitNamesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_names_json'],
      ),
    );
  }

  @override
  $CustomNodesTable createAlias(String alias) {
    return $CustomNodesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<NodeKind, int, int> $converterkind =
      const EnumIndexConverter<NodeKind>(NodeKind.values);
  static JsonTypeConverter2<UnitLabel, int, int> $converterunitLabel =
      const EnumIndexConverter<UnitLabel>(UnitLabel.values);
  static JsonTypeConverter2<UnitLabel?, int?, int?> $converterunitLabeln =
      JsonTypeConverter2.asNullable($converterunitLabel);
}

class CustomNodeRow extends DataClass implements Insertable<CustomNodeRow> {
  final String id;
  final String profileId;
  final String? parentId;
  final String name;
  final String? nameHebrew;
  final int sortOrder;
  final NodeKind kind;
  final UnitLabel? unitLabel;
  final int unitCount;
  final int unitOffset;

  /// When a row's id matches a built-in node it *overrides* that node's fields;
  /// [hidden] true means the node (built-in or custom) is removed from the tree.
  /// This is the per-profile override layer that makes every node editable.
  final bool hidden;

  /// Optional JSON list of real unit names (parsha/siman titles), in unit order.
  final String? unitNamesJson;
  const CustomNodeRow({
    required this.id,
    required this.profileId,
    this.parentId,
    required this.name,
    this.nameHebrew,
    required this.sortOrder,
    required this.kind,
    this.unitLabel,
    required this.unitCount,
    required this.unitOffset,
    required this.hidden,
    this.unitNamesJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_id'] = Variable<String>(profileId);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || nameHebrew != null) {
      map['name_hebrew'] = Variable<String>(nameHebrew);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    {
      map['kind'] = Variable<int>($CustomNodesTable.$converterkind.toSql(kind));
    }
    if (!nullToAbsent || unitLabel != null) {
      map['unit_label'] = Variable<int>(
        $CustomNodesTable.$converterunitLabeln.toSql(unitLabel),
      );
    }
    map['unit_count'] = Variable<int>(unitCount);
    map['unit_offset'] = Variable<int>(unitOffset);
    map['hidden'] = Variable<bool>(hidden);
    if (!nullToAbsent || unitNamesJson != null) {
      map['unit_names_json'] = Variable<String>(unitNamesJson);
    }
    return map;
  }

  CustomNodesCompanion toCompanion(bool nullToAbsent) {
    return CustomNodesCompanion(
      id: Value(id),
      profileId: Value(profileId),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      name: Value(name),
      nameHebrew: nameHebrew == null && nullToAbsent
          ? const Value.absent()
          : Value(nameHebrew),
      sortOrder: Value(sortOrder),
      kind: Value(kind),
      unitLabel: unitLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(unitLabel),
      unitCount: Value(unitCount),
      unitOffset: Value(unitOffset),
      hidden: Value(hidden),
      unitNamesJson: unitNamesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(unitNamesJson),
    );
  }

  factory CustomNodeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomNodeRow(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      name: serializer.fromJson<String>(json['name']),
      nameHebrew: serializer.fromJson<String?>(json['nameHebrew']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      kind: $CustomNodesTable.$converterkind.fromJson(
        serializer.fromJson<int>(json['kind']),
      ),
      unitLabel: $CustomNodesTable.$converterunitLabeln.fromJson(
        serializer.fromJson<int?>(json['unitLabel']),
      ),
      unitCount: serializer.fromJson<int>(json['unitCount']),
      unitOffset: serializer.fromJson<int>(json['unitOffset']),
      hidden: serializer.fromJson<bool>(json['hidden']),
      unitNamesJson: serializer.fromJson<String?>(json['unitNamesJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String>(profileId),
      'parentId': serializer.toJson<String?>(parentId),
      'name': serializer.toJson<String>(name),
      'nameHebrew': serializer.toJson<String?>(nameHebrew),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'kind': serializer.toJson<int>(
        $CustomNodesTable.$converterkind.toJson(kind),
      ),
      'unitLabel': serializer.toJson<int?>(
        $CustomNodesTable.$converterunitLabeln.toJson(unitLabel),
      ),
      'unitCount': serializer.toJson<int>(unitCount),
      'unitOffset': serializer.toJson<int>(unitOffset),
      'hidden': serializer.toJson<bool>(hidden),
      'unitNamesJson': serializer.toJson<String?>(unitNamesJson),
    };
  }

  CustomNodeRow copyWith({
    String? id,
    String? profileId,
    Value<String?> parentId = const Value.absent(),
    String? name,
    Value<String?> nameHebrew = const Value.absent(),
    int? sortOrder,
    NodeKind? kind,
    Value<UnitLabel?> unitLabel = const Value.absent(),
    int? unitCount,
    int? unitOffset,
    bool? hidden,
    Value<String?> unitNamesJson = const Value.absent(),
  }) => CustomNodeRow(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    parentId: parentId.present ? parentId.value : this.parentId,
    name: name ?? this.name,
    nameHebrew: nameHebrew.present ? nameHebrew.value : this.nameHebrew,
    sortOrder: sortOrder ?? this.sortOrder,
    kind: kind ?? this.kind,
    unitLabel: unitLabel.present ? unitLabel.value : this.unitLabel,
    unitCount: unitCount ?? this.unitCount,
    unitOffset: unitOffset ?? this.unitOffset,
    hidden: hidden ?? this.hidden,
    unitNamesJson: unitNamesJson.present
        ? unitNamesJson.value
        : this.unitNamesJson,
  );
  CustomNodeRow copyWithCompanion(CustomNodesCompanion data) {
    return CustomNodeRow(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      name: data.name.present ? data.name.value : this.name,
      nameHebrew: data.nameHebrew.present
          ? data.nameHebrew.value
          : this.nameHebrew,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      kind: data.kind.present ? data.kind.value : this.kind,
      unitLabel: data.unitLabel.present ? data.unitLabel.value : this.unitLabel,
      unitCount: data.unitCount.present ? data.unitCount.value : this.unitCount,
      unitOffset: data.unitOffset.present
          ? data.unitOffset.value
          : this.unitOffset,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      unitNamesJson: data.unitNamesJson.present
          ? data.unitNamesJson.value
          : this.unitNamesJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomNodeRow(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('nameHebrew: $nameHebrew, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('kind: $kind, ')
          ..write('unitLabel: $unitLabel, ')
          ..write('unitCount: $unitCount, ')
          ..write('unitOffset: $unitOffset, ')
          ..write('hidden: $hidden, ')
          ..write('unitNamesJson: $unitNamesJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    parentId,
    name,
    nameHebrew,
    sortOrder,
    kind,
    unitLabel,
    unitCount,
    unitOffset,
    hidden,
    unitNamesJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomNodeRow &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.parentId == this.parentId &&
          other.name == this.name &&
          other.nameHebrew == this.nameHebrew &&
          other.sortOrder == this.sortOrder &&
          other.kind == this.kind &&
          other.unitLabel == this.unitLabel &&
          other.unitCount == this.unitCount &&
          other.unitOffset == this.unitOffset &&
          other.hidden == this.hidden &&
          other.unitNamesJson == this.unitNamesJson);
}

class CustomNodesCompanion extends UpdateCompanion<CustomNodeRow> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<String?> parentId;
  final Value<String> name;
  final Value<String?> nameHebrew;
  final Value<int> sortOrder;
  final Value<NodeKind> kind;
  final Value<UnitLabel?> unitLabel;
  final Value<int> unitCount;
  final Value<int> unitOffset;
  final Value<bool> hidden;
  final Value<String?> unitNamesJson;
  final Value<int> rowid;
  const CustomNodesCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.name = const Value.absent(),
    this.nameHebrew = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.kind = const Value.absent(),
    this.unitLabel = const Value.absent(),
    this.unitCount = const Value.absent(),
    this.unitOffset = const Value.absent(),
    this.hidden = const Value.absent(),
    this.unitNamesJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomNodesCompanion.insert({
    required String id,
    required String profileId,
    this.parentId = const Value.absent(),
    required String name,
    this.nameHebrew = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required NodeKind kind,
    this.unitLabel = const Value.absent(),
    this.unitCount = const Value.absent(),
    this.unitOffset = const Value.absent(),
    this.hidden = const Value.absent(),
    this.unitNamesJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       profileId = Value(profileId),
       name = Value(name),
       kind = Value(kind);
  static Insertable<CustomNodeRow> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<String>? parentId,
    Expression<String>? name,
    Expression<String>? nameHebrew,
    Expression<int>? sortOrder,
    Expression<int>? kind,
    Expression<int>? unitLabel,
    Expression<int>? unitCount,
    Expression<int>? unitOffset,
    Expression<bool>? hidden,
    Expression<String>? unitNamesJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (parentId != null) 'parent_id': parentId,
      if (name != null) 'name': name,
      if (nameHebrew != null) 'name_hebrew': nameHebrew,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (kind != null) 'kind': kind,
      if (unitLabel != null) 'unit_label': unitLabel,
      if (unitCount != null) 'unit_count': unitCount,
      if (unitOffset != null) 'unit_offset': unitOffset,
      if (hidden != null) 'hidden': hidden,
      if (unitNamesJson != null) 'unit_names_json': unitNamesJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomNodesCompanion copyWith({
    Value<String>? id,
    Value<String>? profileId,
    Value<String?>? parentId,
    Value<String>? name,
    Value<String?>? nameHebrew,
    Value<int>? sortOrder,
    Value<NodeKind>? kind,
    Value<UnitLabel?>? unitLabel,
    Value<int>? unitCount,
    Value<int>? unitOffset,
    Value<bool>? hidden,
    Value<String?>? unitNamesJson,
    Value<int>? rowid,
  }) {
    return CustomNodesCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      nameHebrew: nameHebrew ?? this.nameHebrew,
      sortOrder: sortOrder ?? this.sortOrder,
      kind: kind ?? this.kind,
      unitLabel: unitLabel ?? this.unitLabel,
      unitCount: unitCount ?? this.unitCount,
      unitOffset: unitOffset ?? this.unitOffset,
      hidden: hidden ?? this.hidden,
      unitNamesJson: unitNamesJson ?? this.unitNamesJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameHebrew.present) {
      map['name_hebrew'] = Variable<String>(nameHebrew.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(
        $CustomNodesTable.$converterkind.toSql(kind.value),
      );
    }
    if (unitLabel.present) {
      map['unit_label'] = Variable<int>(
        $CustomNodesTable.$converterunitLabeln.toSql(unitLabel.value),
      );
    }
    if (unitCount.present) {
      map['unit_count'] = Variable<int>(unitCount.value);
    }
    if (unitOffset.present) {
      map['unit_offset'] = Variable<int>(unitOffset.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (unitNamesJson.present) {
      map['unit_names_json'] = Variable<String>(unitNamesJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomNodesCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('nameHebrew: $nameHebrew, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('kind: $kind, ')
          ..write('unitLabel: $unitLabel, ')
          ..write('unitCount: $unitCount, ')
          ..write('unitOffset: $unitOffset, ')
          ..write('hidden: $hidden, ')
          ..write('unitNamesJson: $unitNamesJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CustomLayersTable extends CustomLayers
    with TableInfo<$CustomLayersTable, CustomLayerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomLayersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameHebrewMeta = const VerificationMeta(
    'nameHebrew',
  );
  @override
  late final GeneratedColumn<String> nameHebrew = GeneratedColumn<String>(
    'name_hebrew',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    name,
    nameHebrew,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'custom_layers';
  @override
  VerificationContext validateIntegrity(
    Insertable<CustomLayerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('name_hebrew')) {
      context.handle(
        _nameHebrewMeta,
        nameHebrew.isAcceptableOrUnknown(data['name_hebrew']!, _nameHebrewMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, id};
  @override
  CustomLayerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomLayerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nameHebrew: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_hebrew'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $CustomLayersTable createAlias(String alias) {
    return $CustomLayersTable(attachedDatabase, alias);
  }
}

class CustomLayerRow extends DataClass implements Insertable<CustomLayerRow> {
  final String id;
  final String profileId;
  final String name;
  final String? nameHebrew;
  final int sortOrder;
  const CustomLayerRow({
    required this.id,
    required this.profileId,
    required this.name,
    this.nameHebrew,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || nameHebrew != null) {
      map['name_hebrew'] = Variable<String>(nameHebrew);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  CustomLayersCompanion toCompanion(bool nullToAbsent) {
    return CustomLayersCompanion(
      id: Value(id),
      profileId: Value(profileId),
      name: Value(name),
      nameHebrew: nameHebrew == null && nullToAbsent
          ? const Value.absent()
          : Value(nameHebrew),
      sortOrder: Value(sortOrder),
    );
  }

  factory CustomLayerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomLayerRow(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      name: serializer.fromJson<String>(json['name']),
      nameHebrew: serializer.fromJson<String?>(json['nameHebrew']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String>(profileId),
      'name': serializer.toJson<String>(name),
      'nameHebrew': serializer.toJson<String?>(nameHebrew),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  CustomLayerRow copyWith({
    String? id,
    String? profileId,
    String? name,
    Value<String?> nameHebrew = const Value.absent(),
    int? sortOrder,
  }) => CustomLayerRow(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    name: name ?? this.name,
    nameHebrew: nameHebrew.present ? nameHebrew.value : this.nameHebrew,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  CustomLayerRow copyWithCompanion(CustomLayersCompanion data) {
    return CustomLayerRow(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      name: data.name.present ? data.name.value : this.name,
      nameHebrew: data.nameHebrew.present
          ? data.nameHebrew.value
          : this.nameHebrew,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomLayerRow(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('name: $name, ')
          ..write('nameHebrew: $nameHebrew, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, profileId, name, nameHebrew, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomLayerRow &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.name == this.name &&
          other.nameHebrew == this.nameHebrew &&
          other.sortOrder == this.sortOrder);
}

class CustomLayersCompanion extends UpdateCompanion<CustomLayerRow> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<String> name;
  final Value<String?> nameHebrew;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const CustomLayersCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.name = const Value.absent(),
    this.nameHebrew = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomLayersCompanion.insert({
    required String id,
    required String profileId,
    required String name,
    this.nameHebrew = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       profileId = Value(profileId),
       name = Value(name);
  static Insertable<CustomLayerRow> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<String>? name,
    Expression<String>? nameHebrew,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (name != null) 'name': name,
      if (nameHebrew != null) 'name_hebrew': nameHebrew,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomLayersCompanion copyWith({
    Value<String>? id,
    Value<String>? profileId,
    Value<String>? name,
    Value<String?>? nameHebrew,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return CustomLayersCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      nameHebrew: nameHebrew ?? this.nameHebrew,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameHebrew.present) {
      map['name_hebrew'] = Variable<String>(nameHebrew.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomLayersCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('name: $name, ')
          ..write('nameHebrew: $nameHebrew, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RequiredLayerConfigsTable extends RequiredLayerConfigs
    with TableInfo<$RequiredLayerConfigsTable, LayerRequirementRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RequiredLayerConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nodeIdMeta = const VerificationMeta('nodeId');
  @override
  late final GeneratedColumn<String> nodeId = GeneratedColumn<String>(
    'node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitIndexMeta = const VerificationMeta(
    'unitIndex',
  );
  @override
  late final GeneratedColumn<int> unitIndex = GeneratedColumn<int>(
    'unit_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(-1),
  );
  static const VerificationMeta _layersJsonMeta = const VerificationMeta(
    'layersJson',
  );
  @override
  late final GeneratedColumn<String> layersJson = GeneratedColumn<String>(
    'layers_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    nodeId,
    unitIndex,
    layersJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'required_layer_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<LayerRequirementRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('node_id')) {
      context.handle(
        _nodeIdMeta,
        nodeId.isAcceptableOrUnknown(data['node_id']!, _nodeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_nodeIdMeta);
    }
    if (data.containsKey('unit_index')) {
      context.handle(
        _unitIndexMeta,
        unitIndex.isAcceptableOrUnknown(data['unit_index']!, _unitIndexMeta),
      );
    }
    if (data.containsKey('layers_json')) {
      context.handle(
        _layersJsonMeta,
        layersJson.isAcceptableOrUnknown(data['layers_json']!, _layersJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_layersJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, nodeId, unitIndex};
  @override
  LayerRequirementRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LayerRequirementRow(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      nodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}node_id'],
      )!,
      unitIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_index'],
      )!,
      layersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layers_json'],
      )!,
    );
  }

  @override
  $RequiredLayerConfigsTable createAlias(String alias) {
    return $RequiredLayerConfigsTable(attachedDatabase, alias);
  }
}

class LayerRequirementRow extends DataClass
    implements Insertable<LayerRequirementRow> {
  final String profileId;
  final String nodeId;

  /// -1 = the node-level default (applies to all its units); >= 0 = a per-unit
  /// override for that unit index.
  final int unitIndex;

  /// JSON list of required layer ids.
  final String layersJson;
  const LayerRequirementRow({
    required this.profileId,
    required this.nodeId,
    required this.unitIndex,
    required this.layersJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['node_id'] = Variable<String>(nodeId);
    map['unit_index'] = Variable<int>(unitIndex);
    map['layers_json'] = Variable<String>(layersJson);
    return map;
  }

  RequiredLayerConfigsCompanion toCompanion(bool nullToAbsent) {
    return RequiredLayerConfigsCompanion(
      profileId: Value(profileId),
      nodeId: Value(nodeId),
      unitIndex: Value(unitIndex),
      layersJson: Value(layersJson),
    );
  }

  factory LayerRequirementRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LayerRequirementRow(
      profileId: serializer.fromJson<String>(json['profileId']),
      nodeId: serializer.fromJson<String>(json['nodeId']),
      unitIndex: serializer.fromJson<int>(json['unitIndex']),
      layersJson: serializer.fromJson<String>(json['layersJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'nodeId': serializer.toJson<String>(nodeId),
      'unitIndex': serializer.toJson<int>(unitIndex),
      'layersJson': serializer.toJson<String>(layersJson),
    };
  }

  LayerRequirementRow copyWith({
    String? profileId,
    String? nodeId,
    int? unitIndex,
    String? layersJson,
  }) => LayerRequirementRow(
    profileId: profileId ?? this.profileId,
    nodeId: nodeId ?? this.nodeId,
    unitIndex: unitIndex ?? this.unitIndex,
    layersJson: layersJson ?? this.layersJson,
  );
  LayerRequirementRow copyWithCompanion(RequiredLayerConfigsCompanion data) {
    return LayerRequirementRow(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      nodeId: data.nodeId.present ? data.nodeId.value : this.nodeId,
      unitIndex: data.unitIndex.present ? data.unitIndex.value : this.unitIndex,
      layersJson: data.layersJson.present
          ? data.layersJson.value
          : this.layersJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LayerRequirementRow(')
          ..write('profileId: $profileId, ')
          ..write('nodeId: $nodeId, ')
          ..write('unitIndex: $unitIndex, ')
          ..write('layersJson: $layersJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(profileId, nodeId, unitIndex, layersJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LayerRequirementRow &&
          other.profileId == this.profileId &&
          other.nodeId == this.nodeId &&
          other.unitIndex == this.unitIndex &&
          other.layersJson == this.layersJson);
}

class RequiredLayerConfigsCompanion
    extends UpdateCompanion<LayerRequirementRow> {
  final Value<String> profileId;
  final Value<String> nodeId;
  final Value<int> unitIndex;
  final Value<String> layersJson;
  final Value<int> rowid;
  const RequiredLayerConfigsCompanion({
    this.profileId = const Value.absent(),
    this.nodeId = const Value.absent(),
    this.unitIndex = const Value.absent(),
    this.layersJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RequiredLayerConfigsCompanion.insert({
    required String profileId,
    required String nodeId,
    this.unitIndex = const Value.absent(),
    required String layersJson,
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       nodeId = Value(nodeId),
       layersJson = Value(layersJson);
  static Insertable<LayerRequirementRow> custom({
    Expression<String>? profileId,
    Expression<String>? nodeId,
    Expression<int>? unitIndex,
    Expression<String>? layersJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (nodeId != null) 'node_id': nodeId,
      if (unitIndex != null) 'unit_index': unitIndex,
      if (layersJson != null) 'layers_json': layersJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RequiredLayerConfigsCompanion copyWith({
    Value<String>? profileId,
    Value<String>? nodeId,
    Value<int>? unitIndex,
    Value<String>? layersJson,
    Value<int>? rowid,
  }) {
    return RequiredLayerConfigsCompanion(
      profileId: profileId ?? this.profileId,
      nodeId: nodeId ?? this.nodeId,
      unitIndex: unitIndex ?? this.unitIndex,
      layersJson: layersJson ?? this.layersJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (nodeId.present) {
      map['node_id'] = Variable<String>(nodeId.value);
    }
    if (unitIndex.present) {
      map['unit_index'] = Variable<int>(unitIndex.value);
    }
    if (layersJson.present) {
      map['layers_json'] = Variable<String>(layersJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RequiredLayerConfigsCompanion(')
          ..write('profileId: $profileId, ')
          ..write('nodeId: $nodeId, ')
          ..write('unitIndex: $unitIndex, ')
          ..write('layersJson: $layersJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OfferedLayerConfigsTable extends OfferedLayerConfigs
    with TableInfo<$OfferedLayerConfigsTable, OfferedLayerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfferedLayerConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nodeIdMeta = const VerificationMeta('nodeId');
  @override
  late final GeneratedColumn<String> nodeId = GeneratedColumn<String>(
    'node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitIndexMeta = const VerificationMeta(
    'unitIndex',
  );
  @override
  late final GeneratedColumn<int> unitIndex = GeneratedColumn<int>(
    'unit_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(-1),
  );
  static const VerificationMeta _layersJsonMeta = const VerificationMeta(
    'layersJson',
  );
  @override
  late final GeneratedColumn<String> layersJson = GeneratedColumn<String>(
    'layers_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    nodeId,
    unitIndex,
    layersJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offered_layer_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfferedLayerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('node_id')) {
      context.handle(
        _nodeIdMeta,
        nodeId.isAcceptableOrUnknown(data['node_id']!, _nodeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_nodeIdMeta);
    }
    if (data.containsKey('unit_index')) {
      context.handle(
        _unitIndexMeta,
        unitIndex.isAcceptableOrUnknown(data['unit_index']!, _unitIndexMeta),
      );
    }
    if (data.containsKey('layers_json')) {
      context.handle(
        _layersJsonMeta,
        layersJson.isAcceptableOrUnknown(data['layers_json']!, _layersJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_layersJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, nodeId, unitIndex};
  @override
  OfferedLayerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfferedLayerRow(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      nodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}node_id'],
      )!,
      unitIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_index'],
      )!,
      layersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layers_json'],
      )!,
    );
  }

  @override
  $OfferedLayerConfigsTable createAlias(String alias) {
    return $OfferedLayerConfigsTable(attachedDatabase, alias);
  }
}

class OfferedLayerRow extends DataClass implements Insertable<OfferedLayerRow> {
  final String profileId;
  final String nodeId;

  /// -1 = the node-level default (applies to all its units); >= 0 = a per-unit
  /// override for that unit index.
  final int unitIndex;

  /// JSON list of offered layer ids.
  final String layersJson;
  const OfferedLayerRow({
    required this.profileId,
    required this.nodeId,
    required this.unitIndex,
    required this.layersJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['node_id'] = Variable<String>(nodeId);
    map['unit_index'] = Variable<int>(unitIndex);
    map['layers_json'] = Variable<String>(layersJson);
    return map;
  }

  OfferedLayerConfigsCompanion toCompanion(bool nullToAbsent) {
    return OfferedLayerConfigsCompanion(
      profileId: Value(profileId),
      nodeId: Value(nodeId),
      unitIndex: Value(unitIndex),
      layersJson: Value(layersJson),
    );
  }

  factory OfferedLayerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfferedLayerRow(
      profileId: serializer.fromJson<String>(json['profileId']),
      nodeId: serializer.fromJson<String>(json['nodeId']),
      unitIndex: serializer.fromJson<int>(json['unitIndex']),
      layersJson: serializer.fromJson<String>(json['layersJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'nodeId': serializer.toJson<String>(nodeId),
      'unitIndex': serializer.toJson<int>(unitIndex),
      'layersJson': serializer.toJson<String>(layersJson),
    };
  }

  OfferedLayerRow copyWith({
    String? profileId,
    String? nodeId,
    int? unitIndex,
    String? layersJson,
  }) => OfferedLayerRow(
    profileId: profileId ?? this.profileId,
    nodeId: nodeId ?? this.nodeId,
    unitIndex: unitIndex ?? this.unitIndex,
    layersJson: layersJson ?? this.layersJson,
  );
  OfferedLayerRow copyWithCompanion(OfferedLayerConfigsCompanion data) {
    return OfferedLayerRow(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      nodeId: data.nodeId.present ? data.nodeId.value : this.nodeId,
      unitIndex: data.unitIndex.present ? data.unitIndex.value : this.unitIndex,
      layersJson: data.layersJson.present
          ? data.layersJson.value
          : this.layersJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfferedLayerRow(')
          ..write('profileId: $profileId, ')
          ..write('nodeId: $nodeId, ')
          ..write('unitIndex: $unitIndex, ')
          ..write('layersJson: $layersJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(profileId, nodeId, unitIndex, layersJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfferedLayerRow &&
          other.profileId == this.profileId &&
          other.nodeId == this.nodeId &&
          other.unitIndex == this.unitIndex &&
          other.layersJson == this.layersJson);
}

class OfferedLayerConfigsCompanion extends UpdateCompanion<OfferedLayerRow> {
  final Value<String> profileId;
  final Value<String> nodeId;
  final Value<int> unitIndex;
  final Value<String> layersJson;
  final Value<int> rowid;
  const OfferedLayerConfigsCompanion({
    this.profileId = const Value.absent(),
    this.nodeId = const Value.absent(),
    this.unitIndex = const Value.absent(),
    this.layersJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OfferedLayerConfigsCompanion.insert({
    required String profileId,
    required String nodeId,
    this.unitIndex = const Value.absent(),
    required String layersJson,
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       nodeId = Value(nodeId),
       layersJson = Value(layersJson);
  static Insertable<OfferedLayerRow> custom({
    Expression<String>? profileId,
    Expression<String>? nodeId,
    Expression<int>? unitIndex,
    Expression<String>? layersJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (nodeId != null) 'node_id': nodeId,
      if (unitIndex != null) 'unit_index': unitIndex,
      if (layersJson != null) 'layers_json': layersJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OfferedLayerConfigsCompanion copyWith({
    Value<String>? profileId,
    Value<String>? nodeId,
    Value<int>? unitIndex,
    Value<String>? layersJson,
    Value<int>? rowid,
  }) {
    return OfferedLayerConfigsCompanion(
      profileId: profileId ?? this.profileId,
      nodeId: nodeId ?? this.nodeId,
      unitIndex: unitIndex ?? this.unitIndex,
      layersJson: layersJson ?? this.layersJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (nodeId.present) {
      map['node_id'] = Variable<String>(nodeId.value);
    }
    if (unitIndex.present) {
      map['unit_index'] = Variable<int>(unitIndex.value);
    }
    if (layersJson.present) {
      map['layers_json'] = Variable<String>(layersJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfferedLayerConfigsCompanion(')
          ..write('profileId: $profileId, ')
          ..write('nodeId: $nodeId, ')
          ..write('unitIndex: $unitIndex, ')
          ..write('layersJson: $layersJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $LearningEventsTable learningEvents = $LearningEventsTable(this);
  late final $CustomNodesTable customNodes = $CustomNodesTable(this);
  late final $CustomLayersTable customLayers = $CustomLayersTable(this);
  late final $RequiredLayerConfigsTable requiredLayerConfigs =
      $RequiredLayerConfigsTable(this);
  late final $OfferedLayerConfigsTable offeredLayerConfigs =
      $OfferedLayerConfigsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    profiles,
    learningEvents,
    customNodes,
    customLayers,
    requiredLayerConfigs,
    offeredLayerConfigs,
  ];
}

typedef $$ProfilesTableCreateCompanionBuilder =
    ProfilesCompanion Function({
      required String id,
      required String name,
      required DateTime createdAt,
      Value<String> settingsJson,
      Value<int> rowid,
    });
typedef $$ProfilesTableUpdateCompanionBuilder =
    ProfilesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<DateTime> createdAt,
      Value<String> settingsJson,
      Value<int> rowid,
    });

class $$ProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get settingsJson => $composableBuilder(
    column: $table.settingsJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get settingsJson => $composableBuilder(
    column: $table.settingsJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get settingsJson => $composableBuilder(
    column: $table.settingsJson,
    builder: (column) => column,
  );
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProfilesTable,
          ProfileRow,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (
            ProfileRow,
            BaseReferences<_$AppDatabase, $ProfilesTable, ProfileRow>,
          ),
          ProfileRow,
          PrefetchHooks Function()
        > {
  $$ProfilesTableTableManager(_$AppDatabase db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> settingsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                settingsJson: settingsJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required DateTime createdAt,
                Value<String> settingsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                settingsJson: settingsJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProfilesTable,
      ProfileRow,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (ProfileRow, BaseReferences<_$AppDatabase, $ProfilesTable, ProfileRow>),
      ProfileRow,
      PrefetchHooks Function()
    >;
typedef $$LearningEventsTableCreateCompanionBuilder =
    LearningEventsCompanion Function({
      required String id,
      required String profileId,
      required String nodeId,
      required int unitIndex,
      required EventAction action,
      required DateTime occurredAt,
      required DateTime loggedAt,
      Value<int?> durationMin,
      Value<String?> note,
      Value<String?> layersJson,
      Value<int> rowid,
    });
typedef $$LearningEventsTableUpdateCompanionBuilder =
    LearningEventsCompanion Function({
      Value<String> id,
      Value<String> profileId,
      Value<String> nodeId,
      Value<int> unitIndex,
      Value<EventAction> action,
      Value<DateTime> occurredAt,
      Value<DateTime> loggedAt,
      Value<int?> durationMin,
      Value<String?> note,
      Value<String?> layersJson,
      Value<int> rowid,
    });

class $$LearningEventsTableFilterComposer
    extends Composer<_$AppDatabase, $LearningEventsTable> {
  $$LearningEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitIndex => $composableBuilder(
    column: $table.unitIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<EventAction, EventAction, int> get action =>
      $composableBuilder(
        column: $table.action,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get loggedAt => $composableBuilder(
    column: $table.loggedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get layersJson => $composableBuilder(
    column: $table.layersJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LearningEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $LearningEventsTable> {
  $$LearningEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitIndex => $composableBuilder(
    column: $table.unitIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get loggedAt => $composableBuilder(
    column: $table.loggedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get layersJson => $composableBuilder(
    column: $table.layersJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LearningEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LearningEventsTable> {
  $$LearningEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get nodeId =>
      $composableBuilder(column: $table.nodeId, builder: (column) => column);

  GeneratedColumn<int> get unitIndex =>
      $composableBuilder(column: $table.unitIndex, builder: (column) => column);

  GeneratedColumnWithTypeConverter<EventAction, int> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get loggedAt =>
      $composableBuilder(column: $table.loggedAt, builder: (column) => column);

  GeneratedColumn<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get layersJson => $composableBuilder(
    column: $table.layersJson,
    builder: (column) => column,
  );
}

class $$LearningEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LearningEventsTable,
          LearningEventRow,
          $$LearningEventsTableFilterComposer,
          $$LearningEventsTableOrderingComposer,
          $$LearningEventsTableAnnotationComposer,
          $$LearningEventsTableCreateCompanionBuilder,
          $$LearningEventsTableUpdateCompanionBuilder,
          (
            LearningEventRow,
            BaseReferences<
              _$AppDatabase,
              $LearningEventsTable,
              LearningEventRow
            >,
          ),
          LearningEventRow,
          PrefetchHooks Function()
        > {
  $$LearningEventsTableTableManager(
    _$AppDatabase db,
    $LearningEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearningEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearningEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LearningEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> nodeId = const Value.absent(),
                Value<int> unitIndex = const Value.absent(),
                Value<EventAction> action = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<DateTime> loggedAt = const Value.absent(),
                Value<int?> durationMin = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> layersJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningEventsCompanion(
                id: id,
                profileId: profileId,
                nodeId: nodeId,
                unitIndex: unitIndex,
                action: action,
                occurredAt: occurredAt,
                loggedAt: loggedAt,
                durationMin: durationMin,
                note: note,
                layersJson: layersJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String profileId,
                required String nodeId,
                required int unitIndex,
                required EventAction action,
                required DateTime occurredAt,
                required DateTime loggedAt,
                Value<int?> durationMin = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> layersJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearningEventsCompanion.insert(
                id: id,
                profileId: profileId,
                nodeId: nodeId,
                unitIndex: unitIndex,
                action: action,
                occurredAt: occurredAt,
                loggedAt: loggedAt,
                durationMin: durationMin,
                note: note,
                layersJson: layersJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LearningEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LearningEventsTable,
      LearningEventRow,
      $$LearningEventsTableFilterComposer,
      $$LearningEventsTableOrderingComposer,
      $$LearningEventsTableAnnotationComposer,
      $$LearningEventsTableCreateCompanionBuilder,
      $$LearningEventsTableUpdateCompanionBuilder,
      (
        LearningEventRow,
        BaseReferences<_$AppDatabase, $LearningEventsTable, LearningEventRow>,
      ),
      LearningEventRow,
      PrefetchHooks Function()
    >;
typedef $$CustomNodesTableCreateCompanionBuilder =
    CustomNodesCompanion Function({
      required String id,
      required String profileId,
      Value<String?> parentId,
      required String name,
      Value<String?> nameHebrew,
      Value<int> sortOrder,
      required NodeKind kind,
      Value<UnitLabel?> unitLabel,
      Value<int> unitCount,
      Value<int> unitOffset,
      Value<bool> hidden,
      Value<String?> unitNamesJson,
      Value<int> rowid,
    });
typedef $$CustomNodesTableUpdateCompanionBuilder =
    CustomNodesCompanion Function({
      Value<String> id,
      Value<String> profileId,
      Value<String?> parentId,
      Value<String> name,
      Value<String?> nameHebrew,
      Value<int> sortOrder,
      Value<NodeKind> kind,
      Value<UnitLabel?> unitLabel,
      Value<int> unitCount,
      Value<int> unitOffset,
      Value<bool> hidden,
      Value<String?> unitNamesJson,
      Value<int> rowid,
    });

class $$CustomNodesTableFilterComposer
    extends Composer<_$AppDatabase, $CustomNodesTable> {
  $$CustomNodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameHebrew => $composableBuilder(
    column: $table.nameHebrew,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<NodeKind, NodeKind, int> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<UnitLabel?, UnitLabel, int> get unitLabel =>
      $composableBuilder(
        column: $table.unitLabel,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get unitCount => $composableBuilder(
    column: $table.unitCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitOffset => $composableBuilder(
    column: $table.unitOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitNamesJson => $composableBuilder(
    column: $table.unitNamesJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomNodesTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomNodesTable> {
  $$CustomNodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameHebrew => $composableBuilder(
    column: $table.nameHebrew,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitLabel => $composableBuilder(
    column: $table.unitLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitCount => $composableBuilder(
    column: $table.unitCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitOffset => $composableBuilder(
    column: $table.unitOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitNamesJson => $composableBuilder(
    column: $table.unitNamesJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomNodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomNodesTable> {
  $$CustomNodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nameHebrew => $composableBuilder(
    column: $table.nameHebrew,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumnWithTypeConverter<NodeKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumnWithTypeConverter<UnitLabel?, int> get unitLabel =>
      $composableBuilder(column: $table.unitLabel, builder: (column) => column);

  GeneratedColumn<int> get unitCount =>
      $composableBuilder(column: $table.unitCount, builder: (column) => column);

  GeneratedColumn<int> get unitOffset => $composableBuilder(
    column: $table.unitOffset,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<String> get unitNamesJson => $composableBuilder(
    column: $table.unitNamesJson,
    builder: (column) => column,
  );
}

class $$CustomNodesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomNodesTable,
          CustomNodeRow,
          $$CustomNodesTableFilterComposer,
          $$CustomNodesTableOrderingComposer,
          $$CustomNodesTableAnnotationComposer,
          $$CustomNodesTableCreateCompanionBuilder,
          $$CustomNodesTableUpdateCompanionBuilder,
          (
            CustomNodeRow,
            BaseReferences<_$AppDatabase, $CustomNodesTable, CustomNodeRow>,
          ),
          CustomNodeRow,
          PrefetchHooks Function()
        > {
  $$CustomNodesTableTableManager(_$AppDatabase db, $CustomNodesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomNodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomNodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomNodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> nameHebrew = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<NodeKind> kind = const Value.absent(),
                Value<UnitLabel?> unitLabel = const Value.absent(),
                Value<int> unitCount = const Value.absent(),
                Value<int> unitOffset = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<String?> unitNamesJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomNodesCompanion(
                id: id,
                profileId: profileId,
                parentId: parentId,
                name: name,
                nameHebrew: nameHebrew,
                sortOrder: sortOrder,
                kind: kind,
                unitLabel: unitLabel,
                unitCount: unitCount,
                unitOffset: unitOffset,
                hidden: hidden,
                unitNamesJson: unitNamesJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String profileId,
                Value<String?> parentId = const Value.absent(),
                required String name,
                Value<String?> nameHebrew = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required NodeKind kind,
                Value<UnitLabel?> unitLabel = const Value.absent(),
                Value<int> unitCount = const Value.absent(),
                Value<int> unitOffset = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<String?> unitNamesJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomNodesCompanion.insert(
                id: id,
                profileId: profileId,
                parentId: parentId,
                name: name,
                nameHebrew: nameHebrew,
                sortOrder: sortOrder,
                kind: kind,
                unitLabel: unitLabel,
                unitCount: unitCount,
                unitOffset: unitOffset,
                hidden: hidden,
                unitNamesJson: unitNamesJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomNodesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomNodesTable,
      CustomNodeRow,
      $$CustomNodesTableFilterComposer,
      $$CustomNodesTableOrderingComposer,
      $$CustomNodesTableAnnotationComposer,
      $$CustomNodesTableCreateCompanionBuilder,
      $$CustomNodesTableUpdateCompanionBuilder,
      (
        CustomNodeRow,
        BaseReferences<_$AppDatabase, $CustomNodesTable, CustomNodeRow>,
      ),
      CustomNodeRow,
      PrefetchHooks Function()
    >;
typedef $$CustomLayersTableCreateCompanionBuilder =
    CustomLayersCompanion Function({
      required String id,
      required String profileId,
      required String name,
      Value<String?> nameHebrew,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$CustomLayersTableUpdateCompanionBuilder =
    CustomLayersCompanion Function({
      Value<String> id,
      Value<String> profileId,
      Value<String> name,
      Value<String?> nameHebrew,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$CustomLayersTableFilterComposer
    extends Composer<_$AppDatabase, $CustomLayersTable> {
  $$CustomLayersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameHebrew => $composableBuilder(
    column: $table.nameHebrew,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomLayersTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomLayersTable> {
  $$CustomLayersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameHebrew => $composableBuilder(
    column: $table.nameHebrew,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomLayersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomLayersTable> {
  $$CustomLayersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nameHebrew => $composableBuilder(
    column: $table.nameHebrew,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$CustomLayersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomLayersTable,
          CustomLayerRow,
          $$CustomLayersTableFilterComposer,
          $$CustomLayersTableOrderingComposer,
          $$CustomLayersTableAnnotationComposer,
          $$CustomLayersTableCreateCompanionBuilder,
          $$CustomLayersTableUpdateCompanionBuilder,
          (
            CustomLayerRow,
            BaseReferences<_$AppDatabase, $CustomLayersTable, CustomLayerRow>,
          ),
          CustomLayerRow,
          PrefetchHooks Function()
        > {
  $$CustomLayersTableTableManager(_$AppDatabase db, $CustomLayersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomLayersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomLayersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomLayersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> nameHebrew = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomLayersCompanion(
                id: id,
                profileId: profileId,
                name: name,
                nameHebrew: nameHebrew,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String profileId,
                required String name,
                Value<String?> nameHebrew = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomLayersCompanion.insert(
                id: id,
                profileId: profileId,
                name: name,
                nameHebrew: nameHebrew,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomLayersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomLayersTable,
      CustomLayerRow,
      $$CustomLayersTableFilterComposer,
      $$CustomLayersTableOrderingComposer,
      $$CustomLayersTableAnnotationComposer,
      $$CustomLayersTableCreateCompanionBuilder,
      $$CustomLayersTableUpdateCompanionBuilder,
      (
        CustomLayerRow,
        BaseReferences<_$AppDatabase, $CustomLayersTable, CustomLayerRow>,
      ),
      CustomLayerRow,
      PrefetchHooks Function()
    >;
typedef $$RequiredLayerConfigsTableCreateCompanionBuilder =
    RequiredLayerConfigsCompanion Function({
      required String profileId,
      required String nodeId,
      Value<int> unitIndex,
      required String layersJson,
      Value<int> rowid,
    });
typedef $$RequiredLayerConfigsTableUpdateCompanionBuilder =
    RequiredLayerConfigsCompanion Function({
      Value<String> profileId,
      Value<String> nodeId,
      Value<int> unitIndex,
      Value<String> layersJson,
      Value<int> rowid,
    });

class $$RequiredLayerConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $RequiredLayerConfigsTable> {
  $$RequiredLayerConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitIndex => $composableBuilder(
    column: $table.unitIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get layersJson => $composableBuilder(
    column: $table.layersJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RequiredLayerConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $RequiredLayerConfigsTable> {
  $$RequiredLayerConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitIndex => $composableBuilder(
    column: $table.unitIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get layersJson => $composableBuilder(
    column: $table.layersJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RequiredLayerConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RequiredLayerConfigsTable> {
  $$RequiredLayerConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get nodeId =>
      $composableBuilder(column: $table.nodeId, builder: (column) => column);

  GeneratedColumn<int> get unitIndex =>
      $composableBuilder(column: $table.unitIndex, builder: (column) => column);

  GeneratedColumn<String> get layersJson => $composableBuilder(
    column: $table.layersJson,
    builder: (column) => column,
  );
}

class $$RequiredLayerConfigsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RequiredLayerConfigsTable,
          LayerRequirementRow,
          $$RequiredLayerConfigsTableFilterComposer,
          $$RequiredLayerConfigsTableOrderingComposer,
          $$RequiredLayerConfigsTableAnnotationComposer,
          $$RequiredLayerConfigsTableCreateCompanionBuilder,
          $$RequiredLayerConfigsTableUpdateCompanionBuilder,
          (
            LayerRequirementRow,
            BaseReferences<
              _$AppDatabase,
              $RequiredLayerConfigsTable,
              LayerRequirementRow
            >,
          ),
          LayerRequirementRow,
          PrefetchHooks Function()
        > {
  $$RequiredLayerConfigsTableTableManager(
    _$AppDatabase db,
    $RequiredLayerConfigsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RequiredLayerConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RequiredLayerConfigsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RequiredLayerConfigsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> nodeId = const Value.absent(),
                Value<int> unitIndex = const Value.absent(),
                Value<String> layersJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RequiredLayerConfigsCompanion(
                profileId: profileId,
                nodeId: nodeId,
                unitIndex: unitIndex,
                layersJson: layersJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required String nodeId,
                Value<int> unitIndex = const Value.absent(),
                required String layersJson,
                Value<int> rowid = const Value.absent(),
              }) => RequiredLayerConfigsCompanion.insert(
                profileId: profileId,
                nodeId: nodeId,
                unitIndex: unitIndex,
                layersJson: layersJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RequiredLayerConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RequiredLayerConfigsTable,
      LayerRequirementRow,
      $$RequiredLayerConfigsTableFilterComposer,
      $$RequiredLayerConfigsTableOrderingComposer,
      $$RequiredLayerConfigsTableAnnotationComposer,
      $$RequiredLayerConfigsTableCreateCompanionBuilder,
      $$RequiredLayerConfigsTableUpdateCompanionBuilder,
      (
        LayerRequirementRow,
        BaseReferences<
          _$AppDatabase,
          $RequiredLayerConfigsTable,
          LayerRequirementRow
        >,
      ),
      LayerRequirementRow,
      PrefetchHooks Function()
    >;
typedef $$OfferedLayerConfigsTableCreateCompanionBuilder =
    OfferedLayerConfigsCompanion Function({
      required String profileId,
      required String nodeId,
      Value<int> unitIndex,
      required String layersJson,
      Value<int> rowid,
    });
typedef $$OfferedLayerConfigsTableUpdateCompanionBuilder =
    OfferedLayerConfigsCompanion Function({
      Value<String> profileId,
      Value<String> nodeId,
      Value<int> unitIndex,
      Value<String> layersJson,
      Value<int> rowid,
    });

class $$OfferedLayerConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $OfferedLayerConfigsTable> {
  $$OfferedLayerConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitIndex => $composableBuilder(
    column: $table.unitIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get layersJson => $composableBuilder(
    column: $table.layersJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OfferedLayerConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $OfferedLayerConfigsTable> {
  $$OfferedLayerConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitIndex => $composableBuilder(
    column: $table.unitIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get layersJson => $composableBuilder(
    column: $table.layersJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OfferedLayerConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfferedLayerConfigsTable> {
  $$OfferedLayerConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get nodeId =>
      $composableBuilder(column: $table.nodeId, builder: (column) => column);

  GeneratedColumn<int> get unitIndex =>
      $composableBuilder(column: $table.unitIndex, builder: (column) => column);

  GeneratedColumn<String> get layersJson => $composableBuilder(
    column: $table.layersJson,
    builder: (column) => column,
  );
}

class $$OfferedLayerConfigsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OfferedLayerConfigsTable,
          OfferedLayerRow,
          $$OfferedLayerConfigsTableFilterComposer,
          $$OfferedLayerConfigsTableOrderingComposer,
          $$OfferedLayerConfigsTableAnnotationComposer,
          $$OfferedLayerConfigsTableCreateCompanionBuilder,
          $$OfferedLayerConfigsTableUpdateCompanionBuilder,
          (
            OfferedLayerRow,
            BaseReferences<
              _$AppDatabase,
              $OfferedLayerConfigsTable,
              OfferedLayerRow
            >,
          ),
          OfferedLayerRow,
          PrefetchHooks Function()
        > {
  $$OfferedLayerConfigsTableTableManager(
    _$AppDatabase db,
    $OfferedLayerConfigsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfferedLayerConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfferedLayerConfigsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$OfferedLayerConfigsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> nodeId = const Value.absent(),
                Value<int> unitIndex = const Value.absent(),
                Value<String> layersJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfferedLayerConfigsCompanion(
                profileId: profileId,
                nodeId: nodeId,
                unitIndex: unitIndex,
                layersJson: layersJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required String nodeId,
                Value<int> unitIndex = const Value.absent(),
                required String layersJson,
                Value<int> rowid = const Value.absent(),
              }) => OfferedLayerConfigsCompanion.insert(
                profileId: profileId,
                nodeId: nodeId,
                unitIndex: unitIndex,
                layersJson: layersJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OfferedLayerConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OfferedLayerConfigsTable,
      OfferedLayerRow,
      $$OfferedLayerConfigsTableFilterComposer,
      $$OfferedLayerConfigsTableOrderingComposer,
      $$OfferedLayerConfigsTableAnnotationComposer,
      $$OfferedLayerConfigsTableCreateCompanionBuilder,
      $$OfferedLayerConfigsTableUpdateCompanionBuilder,
      (
        OfferedLayerRow,
        BaseReferences<
          _$AppDatabase,
          $OfferedLayerConfigsTable,
          OfferedLayerRow
        >,
      ),
      OfferedLayerRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$LearningEventsTableTableManager get learningEvents =>
      $$LearningEventsTableTableManager(_db, _db.learningEvents);
  $$CustomNodesTableTableManager get customNodes =>
      $$CustomNodesTableTableManager(_db, _db.customNodes);
  $$CustomLayersTableTableManager get customLayers =>
      $$CustomLayersTableTableManager(_db, _db.customLayers);
  $$RequiredLayerConfigsTableTableManager get requiredLayerConfigs =>
      $$RequiredLayerConfigsTableTableManager(_db, _db.requiredLayerConfigs);
  $$OfferedLayerConfigsTableTableManager get offeredLayerConfigs =>
      $$OfferedLayerConfigsTableTableManager(_db, _db.offeredLayerConfigs);
}
