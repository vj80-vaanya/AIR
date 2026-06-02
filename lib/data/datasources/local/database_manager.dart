import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseManager {
  static Database? _database;

  static Future<void> deleteDatabase() async {
    await _database?.close();
    _database = null;
    final dbPath = await getDatabasesPath();
    await databaseFactory.deleteDatabase(join(dbPath, 'security.db'));
  }

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path   = join(dbPath, 'security.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE reputation (
            sender_hash     TEXT PRIMARY KEY,
            last_message_at INTEGER,
            message_count   INTEGER,
            last_call_at    INTEGER,
            call_count      INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE threats (
            id          TEXT PRIMARY KEY,
            channel     TEXT,
            sender      TEXT,
            risk_score  INTEGER,
            category    TEXT,
            reason      TEXT,
            timestamp   TEXT,
            was_blocked INTEGER,
            detail      TEXT,
            feedback    TEXT
          )
        ''');

        // Indexes for date-range and channel-filter queries (avoid full table scans)
        await db.execute(
          'CREATE INDEX idx_threats_timestamp ON threats(timestamp)',
        );
        await db.execute(
          'CREATE INDEX idx_threats_channel ON threats(channel)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE threats ADD COLUMN feedback TEXT',
          );
        }
        if (oldVersion < 3) {
          // Add indexes on existing installs; IF NOT EXISTS is safe to re-run
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_threats_timestamp ON threats(timestamp)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_threats_channel ON threats(channel)',
          );
        }
      },
    );
  }
}
