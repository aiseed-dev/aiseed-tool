import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/location.dart';
import '../models/plot.dart';
import '../models/crop.dart';
import '../models/record.dart';
import '../models/record_photo.dart';
import '../models/crop_reference.dart';
import '../models/observation.dart';

class DatabaseService {
  static const _dbName = 'grow.db';
  static const _dbVersion = 16;

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE record_photos (
              id TEXT PRIMARY KEY,
              record_id TEXT NOT NULL,
              file_path TEXT NOT NULL,
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              FOREIGN KEY (record_id) REFERENCES records(id) ON DELETE CASCADE
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE crops ADD COLUMN cultivation_name TEXT NOT NULL DEFAULT ''",
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            "ALTER TABLE crops ADD COLUMN memo TEXT NOT NULL DEFAULT ''",
          );
        }
        if (oldVersion < 5) {
          final cols = await db.rawQuery('PRAGMA table_info(crops)');
          final colNames = cols.map((c) => c['name'] as String).toSet();
          if (!colNames.contains('name')) {
            await db.execute(
              "ALTER TABLE crops ADD COLUMN name TEXT NOT NULL DEFAULT ''",
            );
          }
          if (!colNames.contains('variety')) {
            await db.execute(
              "ALTER TABLE crops ADD COLUMN variety TEXT NOT NULL DEFAULT ''",
            );
          }
        }
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS plots (
              id TEXT PRIMARY KEY,
              location_id TEXT NOT NULL,
              name TEXT NOT NULL,
              memo TEXT NOT NULL DEFAULT '',
              created_at TEXT NOT NULL,
              FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE CASCADE
            )
          ''');
          final cols = await db.rawQuery('PRAGMA table_info(crops)');
          final colNames = cols.map((c) => c['name'] as String).toSet();
          if (!colNames.contains('plot_id')) {
            await db.execute('ALTER TABLE crops ADD COLUMN plot_id TEXT');
          }
        }
        if (oldVersion < 7) {
          final recCols = await db.rawQuery('PRAGMA table_info(records)');
          final recColNames = recCols.map((c) => c['name'] as String).toSet();
          if (!recColNames.contains('location_id')) {
            await db.execute('ALTER TABLE records ADD COLUMN location_id TEXT');
          }
          if (!recColNames.contains('plot_id')) {
            await db.execute('ALTER TABLE records ADD COLUMN plot_id TEXT');
          }
        }
        if (oldVersion < 8) {
          final cols = await db.rawQuery('PRAGMA table_info(crops)');
          final colNames = cols.map((c) => c['name'] as String).toSet();
          if (!colNames.contains('parent_crop_id')) {
            await db.execute(
              'ALTER TABLE crops ADD COLUMN parent_crop_id TEXT',
            );
          }
          if (!colNames.contains('plot_id')) {
            await db.execute('ALTER TABLE crops ADD COLUMN plot_id TEXT');
          }
          final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='crop_plots'",
          );
          if (tables.isNotEmpty) {
            final links = await db.rawQuery('SELECT crop_id, plot_id FROM crop_plots');
            for (final link in links) {
              await db.execute(
                'UPDATE crops SET plot_id = ? WHERE id = ? AND plot_id IS NULL',
                [link['plot_id'], link['crop_id']],
              );
            }
            await db.execute('DROP TABLE crop_plots');
          }
        }
        if (oldVersion < 9) {
          // Add environment_type to locations
          final locCols = await db.rawQuery('PRAGMA table_info(locations)');
          final locColNames = locCols.map((c) => c['name'] as String).toSet();
          if (!locColNames.contains('environment_type')) {
            await db.execute(
              'ALTER TABLE locations ADD COLUMN environment_type INTEGER NOT NULL DEFAULT 0',
            );
          }
          // Add cover_type and soil_type to plots
          final plotCols = await db.rawQuery('PRAGMA table_info(plots)');
          final plotColNames = plotCols.map((c) => c['name'] as String).toSet();
          if (!plotColNames.contains('cover_type')) {
            await db.execute(
              'ALTER TABLE plots ADD COLUMN cover_type INTEGER NOT NULL DEFAULT 0',
            );
          }
          if (!plotColNames.contains('soil_type')) {
            await db.execute(
              'ALTER TABLE plots ADD COLUMN soil_type INTEGER NOT NULL DEFAULT 0',
            );
          }
          // Create observations and observation_entries tables
          await db.execute('''
            CREATE TABLE IF NOT EXISTS observations (
              id TEXT PRIMARY KEY,
              location_id TEXT,
              plot_id TEXT,
              category INTEGER NOT NULL DEFAULT 0,
              date TEXT NOT NULL,
              memo TEXT NOT NULL DEFAULT '',
              created_at TEXT NOT NULL,
              FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE CASCADE,
              FOREIGN KEY (plot_id) REFERENCES plots(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS observation_entries (
              id TEXT PRIMARY KEY,
              observation_id TEXT NOT NULL,
              key TEXT NOT NULL,
              value REAL NOT NULL,
              unit TEXT NOT NULL DEFAULT '',
              FOREIGN KEY (observation_id) REFERENCES observations(id) ON DELETE CASCADE
            )
          ''');
        }
        if (oldVersion < 10) {
          final locCols = await db.rawQuery('PRAGMA table_info(locations)');
          final locColNames = locCols.map((c) => c['name'] as String).toSet();
          if (!locColNames.contains('latitude')) {
            await db.execute('ALTER TABLE locations ADD COLUMN latitude REAL');
          }
          if (!locColNames.contains('longitude')) {
            await db.execute('ALTER TABLE locations ADD COLUMN longitude REAL');
          }
        }
        if (oldVersion < 11) {
          // Add updated_at to all tables
          final now = DateTime.now().toUtc().toIso8601String();
          // Tables that have created_at
          for (final table in [
            'locations', 'plots', 'crops', 'records',
            'record_photos', 'observations',
          ]) {
            final cols = await db.rawQuery('PRAGMA table_info($table)');
            final colNames = cols.map((c) => c['name'] as String).toSet();
            if (!colNames.contains('updated_at')) {
              await db.execute(
                "ALTER TABLE $table ADD COLUMN updated_at TEXT NOT NULL DEFAULT '$now'",
              );
              await db.execute(
                "UPDATE $table SET updated_at = created_at WHERE updated_at = '$now'",
              );
            }
          }
          // observation_entries has no created_at, handle separately
          {
            final cols = await db.rawQuery('PRAGMA table_info(observation_entries)');
            final colNames = cols.map((c) => c['name'] as String).toSet();
            if (!colNames.contains('updated_at')) {
              await db.execute(
                "ALTER TABLE observation_entries ADD COLUMN updated_at TEXT NOT NULL DEFAULT '$now'",
              );
              // Set updated_at from parent observation's created_at
              await db.execute('''
                UPDATE observation_entries SET updated_at = (
                  SELECT o.created_at FROM observations o
                  WHERE o.id = observation_entries.observation_id
                ) WHERE updated_at = '$now'
                  AND EXISTS (
                    SELECT 1 FROM observations o
                    WHERE o.id = observation_entries.observation_id
                  )
              ''');
            }
          }
          // Add r2_key to record_photos
          final photoCols = await db.rawQuery('PRAGMA table_info(record_photos)');
          final photoColNames = photoCols.map((c) => c['name'] as String).toSet();
          if (!photoColNames.contains('r2_key')) {
            await db.execute('ALTER TABLE record_photos ADD COLUMN r2_key TEXT');
          }
          // Create deleted_records tracking table
          await db.execute('''
            CREATE TABLE IF NOT EXISTS deleted_records (
              id TEXT NOT NULL,
              table_name TEXT NOT NULL,
              deleted_at TEXT NOT NULL,
              PRIMARY KEY (id, table_name)
            )
          ''');
        }
        if (oldVersion < 12) {
          // v12: Remove location_id from crops
          // Remove location_id from crops table if it exists
          // SQLite doesn't support DROP COLUMN before 3.35.0, so recreate
          final cols = await db.rawQuery('PRAGMA table_info(crops)');
          final colNames = cols.map((c) => c['name'] as String).toSet();
          if (colNames.contains('location_id')) {
            await db.execute('''
              CREATE TABLE crops_new (
                id TEXT PRIMARY KEY,
                cultivation_name TEXT NOT NULL DEFAULT '',
                name TEXT NOT NULL DEFAULT '',
                variety TEXT NOT NULL DEFAULT '',
                plot_id TEXT,
                parent_crop_id TEXT,
                memo TEXT NOT NULL DEFAULT '',
                start_date TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY (plot_id) REFERENCES plots(id) ON DELETE SET NULL,
                FOREIGN KEY (parent_crop_id) REFERENCES crops_new(id) ON DELETE SET NULL
              )
            ''');
            await db.execute('''
              INSERT INTO crops_new (id, cultivation_name, name, variety, plot_id, parent_crop_id, memo, start_date, created_at, updated_at)
              SELECT id, cultivation_name, name, variety, plot_id, parent_crop_id, memo, start_date, created_at, updated_at FROM crops
            ''');
            await db.execute('DROP TABLE crops');
            await db.execute('ALTER TABLE crops_new RENAME TO crops');
          }
        }
        if (oldVersion < 13) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS crop_references (
              id TEXT PRIMARY KEY,
              crop_id TEXT NOT NULL,
              type TEXT NOT NULL,
              file_path TEXT,
              url TEXT,
              source_info_id TEXT,
              title TEXT NOT NULL DEFAULT '',
              content TEXT NOT NULL DEFAULT '',
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              FOREIGN KEY (crop_id) REFERENCES crops(id) ON DELETE CASCADE
            )
          ''');
        }
        if (oldVersion < 14) {
          final cols = await db.rawQuery('PRAGMA table_info(crops)');
          final colNames = cols.map((c) => c['name'] as String).toSet();
          if (!colNames.contains('farming_method')) {
            await db.execute(
              'ALTER TABLE crops ADD COLUMN farming_method TEXT',
            );
          }
        }
        if (oldVersion < 15) {
          // v15: Add work_hours and materials to records
          final cols = await db.rawQuery('PRAGMA table_info(records)');
          final colNames = cols.map((c) => c['name'] as String).toSet();
          if (!colNames.contains('work_hours')) {
            await db.execute('ALTER TABLE records ADD COLUMN work_hours REAL');
          }
          if (!colNames.contains('materials')) {
            await db.execute(
              "ALTER TABLE records ADD COLUMN materials TEXT NOT NULL DEFAULT ''",
            );
          }
        }
        if (oldVersion < 16) {
          // v16: Add end_date to crops
          final cols = await db.rawQuery('PRAGMA table_info(crops)');
          final colNames = cols.map((c) => c['name'] as String).toSet();
          if (!colNames.contains('end_date')) {
            await db.execute('ALTER TABLE crops ADD COLUMN end_date TEXT');
          }
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE locations (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        environment_type INTEGER NOT NULL DEFAULT 0,
        latitude REAL,
        longitude REAL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE plots (
        id TEXT PRIMARY KEY,
        location_id TEXT NOT NULL,
        name TEXT NOT NULL,
        cover_type INTEGER NOT NULL DEFAULT 0,
        soil_type INTEGER NOT NULL DEFAULT 0,
        memo TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE crops (
        id TEXT PRIMARY KEY,
        cultivation_name TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL DEFAULT '',
        variety TEXT NOT NULL DEFAULT '',
        plot_id TEXT,
        parent_crop_id TEXT,
        farming_method TEXT,
        memo TEXT NOT NULL DEFAULT '',
        start_date TEXT NOT NULL,
        end_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (plot_id) REFERENCES plots(id) ON DELETE SET NULL,
        FOREIGN KEY (parent_crop_id) REFERENCES crops(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE records (
        id TEXT PRIMARY KEY,
        crop_id TEXT,
        location_id TEXT,
        plot_id TEXT,
        activity_type INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        work_hours REAL,
        materials TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (crop_id) REFERENCES crops(id) ON DELETE CASCADE,
        FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE CASCADE,
        FOREIGN KEY (plot_id) REFERENCES plots(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE record_photos (
        id TEXT PRIMARY KEY,
        record_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        r2_key TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (record_id) REFERENCES records(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE observations (
        id TEXT PRIMARY KEY,
        location_id TEXT,
        plot_id TEXT,
        category INTEGER NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        memo TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE CASCADE,
        FOREIGN KEY (plot_id) REFERENCES plots(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE observation_entries (
        id TEXT PRIMARY KEY,
        observation_id TEXT NOT NULL,
        key TEXT NOT NULL,
        value REAL NOT NULL,
        unit TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL,
        FOREIGN KEY (observation_id) REFERENCES observations(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE crop_references (
        id TEXT PRIMARY KEY,
        crop_id TEXT NOT NULL,
        type TEXT NOT NULL,
        file_path TEXT,
        url TEXT,
        source_info_id TEXT,
        title TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (crop_id) REFERENCES crops(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE deleted_records (
        id TEXT NOT NULL,
        table_name TEXT NOT NULL,
        deleted_at TEXT NOT NULL,
        PRIMARY KEY (id, table_name)
      )
    ''');
  }

  // -- Locations --

  Future<List<Location>> getLocations() async {
    final d = await db;
    final rows = await d.query('locations', orderBy: 'created_at ASC');
    return rows.map(Location.fromMap).toList();
  }

  Future<void> insertLocation(Location location) async {
    final d = await db;
    await d.insert('locations', location.toMap());
  }

  Future<void> updateLocation(Location location) async {
    final d = await db;
    await d.update('locations', location.toMap(),
        where: 'id = ?', whereArgs: [location.id]);
  }

  Future<void> deleteLocation(String id) async {
    final d = await db;
    await d.delete('locations', where: 'id = ?', whereArgs: [id]);
    await _trackDeletion(d, id, 'locations');
  }

  // -- Plots --

  Future<List<Plot>> getPlots(String locationId) async {
    final d = await db;
    final rows = await d.query('plots',
        where: 'location_id = ?',
        whereArgs: [locationId],
        orderBy: 'created_at ASC');
    return rows.map(Plot.fromMap).toList();
  }

  Future<List<Plot>> getAllPlots() async {
    final d = await db;
    final rows = await d.query('plots', orderBy: 'created_at ASC');
    return rows.map(Plot.fromMap).toList();
  }

  Future<void> insertPlot(Plot plot) async {
    final d = await db;
    await d.insert('plots', plot.toMap());
  }

  Future<void> updatePlot(Plot plot) async {
    final d = await db;
    await d.update('plots', plot.toMap(),
        where: 'id = ?', whereArgs: [plot.id]);
  }

  Future<void> deletePlot(String id) async {
    final d = await db;
    await d.delete('plots', where: 'id = ?', whereArgs: [id]);
    await _trackDeletion(d, id, 'plots');
  }

  // -- Crops --

  Future<List<Crop>> getCrops() async {
    final d = await db;
    final rows = await d.query('crops', orderBy: 'start_date DESC');
    return rows.map(Crop.fromMap).toList();
  }

  Future<List<Crop>> getCropsByPlot(String plotId) async {
    final d = await db;
    final rows = await d.query('crops',
        where: 'plot_id = ?',
        whereArgs: [plotId],
        orderBy: 'start_date DESC');
    return rows.map(Crop.fromMap).toList();
  }

  Future<List<Crop>> getChildCrops(String parentCropId) async {
    final d = await db;
    final rows = await d.query('crops',
        where: 'parent_crop_id = ?',
        whereArgs: [parentCropId],
        orderBy: 'start_date DESC');
    return rows.map(Crop.fromMap).toList();
  }

  Future<void> insertCrop(Crop crop) async {
    final d = await db;
    await d.insert('crops', crop.toMap());
  }

  Future<void> updateCrop(Crop crop) async {
    final d = await db;
    await d.update('crops', crop.toMap(),
        where: 'id = ?', whereArgs: [crop.id]);
  }

  Future<void> deleteCrop(String id) async {
    final d = await db;
    await d.delete('crops', where: 'id = ?', whereArgs: [id]);
    await _trackDeletion(d, id, 'crops');
  }

  // -- Records --

  Future<List<GrowRecord>> getRecords({
    String? cropId,
    String? locationId,
    String? plotId,
  }) async {
    final d = await db;
    if (cropId != null) {
      final rows = await d.query('records',
          where: 'crop_id = ?',
          whereArgs: [cropId],
          orderBy: 'date DESC');
      return rows.map(GrowRecord.fromMap).toList();
    }
    if (plotId != null) {
      final rows = await d.query('records',
          where: 'plot_id = ?',
          whereArgs: [plotId],
          orderBy: 'date DESC');
      return rows.map(GrowRecord.fromMap).toList();
    }
    if (locationId != null) {
      final rows = await d.query('records',
          where: 'location_id = ?',
          whereArgs: [locationId],
          orderBy: 'date DESC');
      return rows.map(GrowRecord.fromMap).toList();
    }
    final rows = await d.query('records', orderBy: 'date DESC');
    return rows.map(GrowRecord.fromMap).toList();
  }

  Future<void> insertRecord(GrowRecord record) async {
    final d = await db;
    await d.insert('records', record.toMap());
  }

  Future<void> updateRecord(GrowRecord record) async {
    final d = await db;
    await d.update('records', record.toMap(),
        where: 'id = ?', whereArgs: [record.id]);
  }

  Future<void> deleteRecord(String id) async {
    final d = await db;
    await d.delete('records', where: 'id = ?', whereArgs: [id]);
    await _trackDeletion(d, id, 'records');
  }

  // -- Record Photos --

  Future<List<RecordPhoto>> getPhotos(String recordId) async {
    final d = await db;
    final rows = await d.query('record_photos',
        where: 'record_id = ?',
        whereArgs: [recordId],
        orderBy: 'sort_order ASC');
    return rows.map(RecordPhoto.fromMap).toList();
  }

  Future<void> insertPhoto(RecordPhoto photo) async {
    final d = await db;
    await d.insert('record_photos', photo.toMap());
  }

  Future<void> deletePhoto(String id) async {
    final d = await db;
    await d.delete('record_photos', where: 'id = ?', whereArgs: [id]);
    await _trackDeletion(d, id, 'record_photos');
  }

  // -- Observations --

  Future<List<Observation>> getObservations({
    String? locationId,
    String? plotId,
  }) async {
    final d = await db;
    if (plotId != null) {
      final rows = await d.query('observations',
          where: 'plot_id = ?',
          whereArgs: [plotId],
          orderBy: 'date DESC');
      return rows.map(Observation.fromMap).toList();
    }
    if (locationId != null) {
      final rows = await d.query('observations',
          where: 'location_id = ?',
          whereArgs: [locationId],
          orderBy: 'date DESC');
      return rows.map(Observation.fromMap).toList();
    }
    final rows = await d.query('observations', orderBy: 'date DESC');
    return rows.map(Observation.fromMap).toList();
  }

  Future<void> insertObservation(Observation obs) async {
    final d = await db;
    await d.insert('observations', obs.toMap());
  }

  Future<void> updateObservation(Observation obs) async {
    final d = await db;
    await d.update('observations', obs.toMap(),
        where: 'id = ?', whereArgs: [obs.id]);
  }

  Future<void> deleteObservation(String id) async {
    final d = await db;
    await d.delete('observations', where: 'id = ?', whereArgs: [id]);
    await _trackDeletion(d, id, 'observations');
  }

  // -- Observation Entries --

  Future<List<ObservationEntry>> getObservationEntries(
      String observationId) async {
    final d = await db;
    final rows = await d.query('observation_entries',
        where: 'observation_id = ?', whereArgs: [observationId]);
    return rows.map(ObservationEntry.fromMap).toList();
  }

  Future<void> insertObservationEntry(ObservationEntry entry) async {
    final d = await db;
    await d.insert('observation_entries', entry.toMap());
  }

  Future<void> deleteObservationEntry(String id) async {
    final d = await db;
    await d.delete('observation_entries', where: 'id = ?', whereArgs: [id]);
    await _trackDeletion(d, id, 'observation_entries');
  }

  Future<void> setObservationEntries(
      String observationId, List<ObservationEntry> entries) async {
    final d = await db;
    await d.delete('observation_entries',
        where: 'observation_id = ?', whereArgs: [observationId]);
    for (final entry in entries) {
      await d.insert('observation_entries', entry.toMap());
    }
  }

  // -- Crop References --

  Future<List<CropReference>> getCropReferences(String cropId) async {
    final d = await db;
    final rows = await d.query('crop_references',
        where: 'crop_id = ?',
        whereArgs: [cropId],
        orderBy: 'sort_order ASC, created_at ASC');
    return rows.map(CropReference.fromMap).toList();
  }

  Future<void> insertCropReference(CropReference ref) async {
    final d = await db;
    await d.insert('crop_references', ref.toMap());
  }

  Future<void> deleteCropReference(String id) async {
    final d = await db;
    await d.delete('crop_references', where: 'id = ?', whereArgs: [id]);
    await _trackDeletion(d, id, 'crop_references');
  }

  // -- Sync helpers --

  Future<void> _trackDeletion(Database d, String id, String tableName) async {
    await d.insert(
      'deleted_records',
      {
        'id': id,
        'table_name': tableName,
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all rows from [table] updated after [since].
  Future<List<Map<String, dynamic>>> getUpdatedRows(
      String table, String since) async {
    final d = await db;
    return d.query(table, where: 'updated_at > ?', whereArgs: [since]);
  }

  /// Get deleted records tracked after [since].
  Future<List<Map<String, dynamic>>> getDeletedRecords(String since) async {
    final d = await db;
    return d.query('deleted_records',
        where: 'deleted_at > ?', whereArgs: [since]);
  }

  /// Upsert a row from sync data (used by SyncService).
  Future<void> upsertRow(String table, Map<String, dynamic> row) async {
    final d = await db;
    await d.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Apply a remote deletion (used by SyncService).
  Future<void> applyDeletion(String table, String id) async {
    final d = await db;
    await d.delete(table, where: 'id = ?', whereArgs: [id]);
  }
}
