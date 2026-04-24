import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final String path = join(await getDatabasesPath(), 'plant_pulse.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE scans(
            id TEXT PRIMARY KEY,
            disease_name TEXT,
            confidence REAL,
            causal_factor TEXT,
            image_path TEXT,
            image_url TEXT,
            is_synced INTEGER DEFAULT 0,
            lat REAL,
            lng REAL,
            created_at TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE scans ADD COLUMN lat REAL');
          await db.execute('ALTER TABLE scans ADD COLUMN lng REAL');
        }
      },
    );
  }

  Future<void> insertScan(Map<String, dynamic> scan) async {
    final db = await database;
    await db.insert('scans', scan, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedScans() async {
    final db = await database;
    return await db.query('scans', where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<void> markAsSynced(String id, String imageUrl) async {
    final db = await database;
    await db.update(
      'scans',
      {'is_synced': 1, 'image_url': imageUrl},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getAllScans() async {
    final db = await database;
    return await db.query('scans', orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>> getWeeklyStats() async {
    final db = await database;
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7)).toIso8601String();

    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as total FROM scans WHERE created_at >= ?', 
      [weekAgo]
    );

    final commonResult = await db.rawQuery(
      'SELECT disease_name, COUNT(disease_name) as freq FROM scans WHERE created_at >= ? GROUP BY disease_name ORDER BY freq DESC LIMIT 1',
      [weekAgo]
    );

    return {
      'count': countResult.first['total'] as int,
      'most_common': commonResult.isNotEmpty ? commonResult.first['disease_name'] as String : 'None',
    };
  }
}
