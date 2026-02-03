import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/location.dart';
import '../models/plot.dart';
import '../models/crop.dart';
import '../models/record.dart';
import '../models/record_photo.dart';

class DatabaseService {
  static const _dbName = 'grow.db';
  static const _dbVersion = 7;

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
          // crop_plots many-to-many table
          await db.execute('''
            CREATE TABLE crop_plots (
              crop_id TEXT NOT NULL,
              plot_id TEXT NOT NULL,
              created_at TEXT NOT NULL,
              PRIMARY KEY (crop_id, plot_id),
              FOREIGN KEY (crop_id) REFERENCES crops(id) ON DELETE CASCADE,
              FOREIGN KEY (plot_id) REFERENCES plots(id) ON DELETE CASCADE
            )
          ''');
          // Migrate existing crop->plot links to crop_plots
          final existing = await db.rawQuery(
            'SELECT id, plot_id FROM crops WHERE plot_id IS NOT NULL',
          );
          for (final row in existing) {
            await db.insert('crop_plots', {
              'crop_id': row['id'],
              'plot_id': row['plot_id'],
              'created_at': DateTime.now().toIso8601String(),
            });
          }
          // Add location_id and plot_id to records
          await db.execute('ALTER TABLE records ADD COLUMN location_id TEXT');
          await db.execute('ALTER TABLE records ADD COLUMN plot_id TEXT');
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
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE plots (
        id TEXT PRIMARY KEY,
        location_id TEXT NOT NULL,
        name TEXT NOT NULL,
        memo TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE crops (
        id TEXT PRIMARY KEY,
        cultivation_name TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL DEFAULT '',
        variety TEXT NOT NULL DEFAULT '',
        memo TEXT NOT NULL DEFAULT '',
        start_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE crop_plots (
        crop_id TEXT NOT NULL,
        plot_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY (crop_id, plot_id),
        FOREIGN KEY (crop_id) REFERENCES crops(id) ON DELETE CASCADE,
        FOREIGN KEY (plot_id) REFERENCES plots(id) ON DELETE CASCADE
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
        created_at TEXT NOT NULL,
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
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (record_id) REFERENCES records(id) ON DELETE CASCADE
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
  }

  // -- Crops --

  Future<List<Crop>> getCrops() async {
    final d = await db;
    final rows = await d.query('crops', orderBy: 'start_date DESC');
    return rows.map(Crop.fromMap).toList();
  }

  Future<List<Crop>> getCropsByPlot(String plotId) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT c.* FROM crops c
      INNER JOIN crop_plots cp ON c.id = cp.crop_id
      WHERE cp.plot_id = ?
      ORDER BY c.start_date DESC
    ''', [plotId]);
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
  }

  // -- Crop-Plot links --

  Future<List<String>> getCropPlotIds(String cropId) async {
    final d = await db;
    final rows = await d.query('crop_plots',
        where: 'crop_id = ?', whereArgs: [cropId]);
    return rows.map((r) => r['plot_id'] as String).toList();
  }

  Future<void> linkCropToPlot(String cropId, String plotId) async {
    final d = await db;
    await d.insert('crop_plots', {
      'crop_id': cropId,
      'plot_id': plotId,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> unlinkCropFromPlot(String cropId, String plotId) async {
    final d = await db;
    await d.delete('crop_plots',
        where: 'crop_id = ? AND plot_id = ?',
        whereArgs: [cropId, plotId]);
  }

  Future<void> setCropPlots(String cropId, List<String> plotIds) async {
    final d = await db;
    await d.delete('crop_plots',
        where: 'crop_id = ?', whereArgs: [cropId]);
    for (final plotId in plotIds) {
      await d.insert('crop_plots', {
        'crop_id': cropId,
        'plot_id': plotId,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
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
  }
}
