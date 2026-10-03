import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// 应用设置 DAO（键值对）。
class SettingsDao {
  SettingsDao(this._db);

  final AppDatabase _db;

  $AppSettingsTable get _table => _db.appSettings;

  Future<String?> get(String key) async {
    final AppSetting? row = await (_db.select(_table)
          ..where(($AppSettingsTable t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watch(String key) => (_db.select(_table)
        ..where(($AppSettingsTable t) => t.key.equals(key)))
      .watchSingleOrNull()
      .map((AppSetting? row) => row?.value);

  Future<Map<String, String>> getAll() async {
    final List<AppSetting> rows = await _db.select(_table).get();
    return <String, String>{
      for (final AppSetting row in rows) row.key: row.value,
    };
  }

  /// 写入或覆盖。
  Future<void> set(String key, String value) async {
    await _db.into(_table).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: key,
            value: value,
            updatedAt: Value<DateTime>(DateTime.now()),
          ),
        );
  }

  Future<void> setAll(Map<String, String> values) async {
    await _db.batch((Batch b) {
      b.insertAllOnConflictUpdate(
        _table,
        values.entries
            .map(
              (MapEntry<String, String> e) => AppSettingsCompanion.insert(
                key: e.key,
                value: e.value,
                updatedAt: Value<DateTime>(DateTime.now()),
              ),
            )
            .toList(),
      );
    });
  }

  Future<int> delete(String key) =>
      (_db.delete(_table)..where(($AppSettingsTable t) => t.key.equals(key)))
          .go();

  Future<int> deleteAll() => _db.delete(_table).go();
}
