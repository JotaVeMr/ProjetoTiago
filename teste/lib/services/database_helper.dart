import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/medicamento.dart';
import '../models/usuario.dart';

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
      version: 3,
      onConfigure: (db) async {
        
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Usuários
    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        sobrenome TEXT DEFAULT '',
        sexo TEXT DEFAULT 'outro',
        pin TEXT DEFAULT ''
      )
    ''');

    // Medicamentos
    await db.execute('''
      CREATE TABLE medicamentos (
        id INTEGER PRIMARY KEY,
        usuarioId INTEGER,
        nome TEXT NOT NULL,
        tipo TEXT,
        dose TEXT,
        dataHoraAgendamento TEXT,
        dataInicio TEXT,
        dataFim TEXT,
        isTaken INTEGER DEFAULT 0,
        isIgnored INTEGER DEFAULT 0,
        isPendente INTEGER DEFAULT 0,
        FOREIGN KEY (usuarioId) REFERENCES usuarios(id) ON DELETE CASCADE
      )
    ''');

    // Tratamentos 
    await db.execute('''
      CREATE TABLE tratamentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicamentoId INTEGER,
        inicio TEXT,
        fim TEXT,
        repeticao TEXT,
        FOREIGN KEY (medicamentoId) REFERENCES medicamentos(id) ON DELETE CASCADE
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE medicamentos ADD COLUMN dataInicio TEXT");
      await db.execute("ALTER TABLE medicamentos ADD COLUMN dataFim TEXT");
    }
    
    if (oldVersion < 3) {
      await db.execute('PRAGMA foreign_keys = OFF');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS usuarios (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nome TEXT NOT NULL,
          sobrenome TEXT DEFAULT '',
          sexo TEXT DEFAULT 'outro',
          pin TEXT DEFAULT ''
        )
      ''');

      final cols = await db.rawQuery(
          "PRAGMA table_info(medicamentos)"); 
      final hasUsuarioId =
          cols.any((c) => (c['name'] as String?)?.toLowerCase() == 'usuarioid');
      if (!hasUsuarioId) {
        await db.execute(
            "ALTER TABLE medicamentos ADD COLUMN usuarioId INTEGER REFERENCES usuarios(id)");
      }

      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  
  Future<int> insertUsuario(Usuario usuario) async {
    final db = await database;
    return await db.insert(
      'usuarios',
      usuario.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateUsuario(Usuario usuario) async {
    final db = await database;
    if (usuario.id == null) return 0;
    return await db.update(
      'usuarios',
      usuario.toMap(),
      where: 'id = ?',
      whereArgs: [usuario.id],
    );
  }

  Future<List<Usuario>> getUsuarios() async {
    final db = await database;
    final maps = await db.query('usuarios', orderBy: 'nome COLLATE NOCASE');
    return maps.map((u) => Usuario.fromMap(u)).toList();
  }

  Future<Usuario?> getUsuarioById(int id) async {
    final db = await database;
    final maps =
        await db.query('usuarios', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isNotEmpty) return Usuario.fromMap(maps.first);
    return null;
  }

  Future<int> deleteUsuario(int id) async {
    final db = await database;
    
    return await db.delete('usuarios', where: 'id = ?', whereArgs: [id]);
  }

  
  Future<int> insertMedicamento(Medicamento med) async {
    final db = await database;
    return await db.insert(
      'medicamentos',
      med.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateMedicamento(Medicamento med) async {
    final db = await database;
    if (med.id == null) return insertMedicamento(med);
    return await db.update(
      'medicamentos',
      med.toMap(),
      where: 'id = ?',
      whereArgs: [med.id],
    );
  }

  Future<int> deleteMedicamento(int id) async {
    final db = await database;
    return await db.delete('medicamentos', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Medicamento>> getMedicamentos({int? usuarioId}) async {
    final db = await database;
    final maps = await db.query(
      'medicamentos',
      where: usuarioId != null ? 'usuarioId = ?' : null,
      whereArgs: usuarioId != null ? [usuarioId] : null,
      orderBy: 'dataHoraAgendamento ASC',
    );
    return maps.map((m) => Medicamento.fromMap(m)).toList();
  }

  Future<int> deleteAllMedicamentosByUsuario(int usuarioId) async {
    final db = await database;
    return await db
        .delete('medicamentos', where: 'usuarioId = ?', whereArgs: [usuarioId]);
  }

  
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
