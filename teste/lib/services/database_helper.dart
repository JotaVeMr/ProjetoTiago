import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medicamento.dart';
import '../models/usuario.dart';
import 'package:intl/intl.dart';

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
      version: 8, // 🔹 ATUALIZADO PARA 8
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // ====== USUÁRIOS ======
    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        sobrenome TEXT DEFAULT '',
        sexo TEXT DEFAULT 'outro',
        pin TEXT DEFAULT ''
      )
    ''');

    // ====== MEDICAMENTOS ======
    await db.execute('''
      CREATE TABLE medicamentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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
        fotoPath TEXT,              
        FOREIGN KEY (usuarioId) REFERENCES usuarios(id) ON DELETE CASCADE
      )
    ''');

    // ====== TRATAMENTOS ======
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

    // ====== DOSES CONFIRMADAS ======
    await db.execute('''
      CREATE TABLE dose_confirmada (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicamentoId INTEGER,
        usuarioId INTEGER,
        horarioConfirmacao TEXT,
        status TEXT,
        FOREIGN KEY (medicamentoId) REFERENCES medicamentos(id) ON DELETE CASCADE,
        FOREIGN KEY (usuarioId) REFERENCES usuarios(id) ON DELETE CASCADE
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS dose_confirmada (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          medicamentoId INTEGER,
          usuarioId INTEGER,
          horarioConfirmacao TEXT,
          status TEXT,
          FOREIGN KEY (medicamentoId) REFERENCES medicamentos(id) ON DELETE CASCADE,
          FOREIGN KEY (usuarioId) REFERENCES usuarios(id) ON DELETE CASCADE
        )
      ''');
    }

    // 🔹 NOVA VERSÃO: adiciona coluna fotoPath se for banco antigo
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE medicamentos ADD COLUMN fotoPath TEXT');
    }
  }

  //  ================= USUÁRIOS =================
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

  //  ================= MEDICAMENTOS =================
  Future<int> insertMedicamento(Medicamento med) async {
    final db = await database;
    final id = await db.insert(
      'medicamentos',
      med.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    med.id = id;
    return id;
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

  //  ================= TRATAMENTOS =================
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

  //  ================= DOSES CONFIRMADAS =================
  Future<void> registrarDose({
    required int medicamentoId,
    required String status,
  }) async {
    final db = await database;

    // garantindo status padronizado
    status = status.toUpperCase().trim();

    final hoje = DateTime.now();
    final dataHoje = DateFormat("yyyy-MM-dd").format(hoje);

    final jaExiste = await db.query(
      'dose_confirmada',
      where: '''
            medicamentoId = ? 
            AND substr(horarioConfirmacao, 1, 10) = ?
          ''',
      whereArgs: [medicamentoId, dataHoje],
    );

    // Descobre o usuário
    final med = await db.query(
      'medicamentos',
      where: 'id = ?',
      whereArgs: [medicamentoId],
    );

    final usuarioId = med.isNotEmpty ? (med.first['usuarioId'] as int) : 0;

    if (jaExiste.isEmpty) {
      // INSERE
      await db.insert('dose_confirmada', {
        'medicamentoId': medicamentoId,
        'usuarioId': usuarioId,
        'horarioConfirmacao': hoje.toIso8601String(),
        'status': status,
      });
    } else {
      // ATUALIZA
      await db.update(
        'dose_confirmada',
        {
          'status': status,
          'horarioConfirmacao': hoje.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [jaExiste.first['id']],
      );
    }
  }

  Future<List<Map<String, dynamic>>> getDosesConfirmadas(
      {int? usuarioId}) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT D.id, D.horarioConfirmacao, D.status, M.nome AS medicamento
      FROM dose_confirmada D
      JOIN medicamentos M ON D.medicamentoId = M.id
      ${usuarioId != null ? 'WHERE D.usuarioId = ?' : ''}
      ORDER BY D.horarioConfirmacao DESC
    ''', usuarioId != null ? [usuarioId] : []);
    return result;
  }

  //  ================= PENDENTES =================
  Future<void> marcarPendentesComoNaoTomados() async {
    final db = await database;
    final agora = DateTime.now().toIso8601String();

    final pendentes = await db.query(
      'medicamentos',
      where: 'dataHoraAgendamento < ? AND isTaken = 0 AND isIgnored = 0',
      whereArgs: [agora],
    );

    for (var med in pendentes) {
      final usuarioId = med['usuarioId'] ?? 0;

      await db.update(
        'medicamentos',
        {'isPendente': 1},
        where: 'id = ?',
        whereArgs: [med['id']],
      );

      final existe = await db.query(
        'dose_confirmada',
        where: 'medicamentoId = ? AND status = ?',
        whereArgs: [med['id'], 'NÃO TOMADO'],
        limit: 1,
      );

      if (existe.isEmpty) {
        await db.insert('dose_confirmada', {
          'medicamentoId': med['id'],
          'usuarioId': usuarioId,
          'horarioConfirmacao': agora,
          'status': 'NÃO TOMADO',
        });
      }
    }
  }

  //  ================= BACKUP / RESTAURAÇÃO =================
  Future<String> exportarBackup() async {
    final db = await database;

    final usuarios = await db.query('usuarios');
    final medicamentos = await db.query('medicamentos');
    final tratamentos = await db.query('tratamentos');
    final doses = await db.query('dose_confirmada');

    final prefs = await SharedPreferences.getInstance();
    final prefsData = <String, dynamic>{};
    for (var key in prefs.getKeys()) {
      prefsData[key] = prefs.get(key);
    }

    final backup = jsonEncode({
      'usuarios': usuarios,
      'medicamentos': medicamentos,
      'tratamentos': tratamentos,
      'doses_confirmadas': doses,
      'shared_preferences': prefsData,
    });

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/backup_pharmsync.json');
    await file.writeAsString(backup);

    return file.path;
  }

  Future<void> importarBackup(String caminho) async {
    final db = await database;
    final file = File(caminho);
    final data = jsonDecode(await file.readAsString());

    await db.transaction((txn) async {
      await txn.delete('dose_confirmada');
      await txn.delete('tratamentos');
      await txn.delete('medicamentos');
      await txn.delete('usuarios');

      for (var u in data['usuarios']) {
        await txn.insert('usuarios', Map<String, dynamic>.from(u));
      }
      for (var m in data['medicamentos']) {
        await txn.insert('medicamentos', Map<String, dynamic>.from(m));
      }
      for (var t in data['tratamentos']) {
        await txn.insert('tratamentos', Map<String, dynamic>.from(t));
      }
      for (var d in data['doses_confirmadas']) {
        await txn.insert('dose_confirmada', Map<String, dynamic>.from(d));
      }
    });

    final prefs = await SharedPreferences.getInstance();
    final prefsData = Map<String, dynamic>.from(data['shared_preferences']);
    for (var key in prefsData.keys) {
      final value = prefsData[key];
      if (value is bool) prefs.setBool(key, value);
      if (value is int) prefs.setInt(key, value);
      if (value is double) prefs.setDouble(key, value);
      if (value is String) prefs.setString(key, value);
    }
  }

  // ================= RESET / DEBUG =================
  Future<void> resetDatabase() async {
    final db = await database;
    await db.delete('dose_confirmada');
    await db.delete('tratamentos');
    await db.delete('medicamentos');
    await db.delete('usuarios');
    print("🧹 Todas as tabelas foram limpas com sucesso!");
  }
}
