import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/medicamento.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pharmsync.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 2, // ALTEREI versão p/ recriar com novos campos
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE medicamentos (
        id INTEGER PRIMARY KEY,
        nome TEXT NOT NULL,
        tipo TEXT,
        dose TEXT,
        dataHoraAgendamento TEXT,
        dataInicio TEXT,
        dataFim TEXT,
        isTaken INTEGER DEFAULT 0,
        isIgnored INTEGER DEFAULT 0,
        isPendente INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE tratamentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicamentoId INTEGER,
        inicio TEXT,
        fim TEXT,
        repeticao TEXT,
        FOREIGN KEY (medicamentoId) REFERENCES medicamentos(id)
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE medicamentos ADD COLUMN dataInicio TEXT");
      await db.execute("ALTER TABLE medicamentos ADD COLUMN dataFim TEXT");
    }
  }

  // ---------- Medicamentos CRUD ----------
  Future<int> insertMedicamento(Medicamento med) async {
    final db = await database;
    return await db.insert('medicamentos', med.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateMedicamento(Medicamento med) async {
    final db = await database;
    if (med.id == null) {
      return insertMedicamento(med);
    }
    return await db.update('medicamentos', med.toMap(),
        where: 'id = ?', whereArgs: [med.id]);
  }

  Future<int> deleteMedicamento(int id) async {
    final db = await database;
    return await db.delete('medicamentos', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Medicamento>> getMedicamentos() async {
    final db = await database;
    final maps = await db.query('medicamentos');
    return maps.map((m) => Medicamento.fromMap(m)).toList();
  }

  // ---------- Tratamentos ----------
  Future<int> insertTratamento(Map<String, dynamic> t) async {
    final db = await database;
    return await db.insert('tratamentos', t,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getTratamentos() async {
    final db = await database;
    return await db.query('tratamentos');
  }

  Future<int> deleteTratamento(int id) async {
    final db = await database;
    return await db.delete('tratamentos', where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
