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
      version: 6,
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
    if (oldVersion < 6) {
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
  }

  // ================= USUÁRIOS =================
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

  // ================= MEDICAMENTOS =================
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

  // ================= TRATAMENTOS =================
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

  // ================= DOSES CONFIRMADAS =================
  Future<void> registrarDose({
  required int medicamentoId,
  required String status,
}) async {
  final db = await database;
  final med = await db.query(
    'medicamentos',
    columns: ['usuarioId'],
    where: 'id = ?',
    whereArgs: [medicamentoId],
  );
  final usuarioId = med.isNotEmpty ? (med.first['usuarioId'] as int?) ?? 0 : 0;

  // 🔎 Verifica se já existe um registro recente para este medicamento
  final jaExiste = await db.query(
    'dose_confirmada',
    where:
        'medicamentoId = ? AND DATE(horarioConfirmacao) = DATE("now")',
    whereArgs: [medicamentoId],
  );

  if (jaExiste.isEmpty) {
    // ✅ Só insere se ainda não houver registro do dia
    await db.insert('dose_confirmada', {
      'medicamentoId': medicamentoId,
      'usuarioId': usuarioId,
      'horarioConfirmacao': DateTime.now().toIso8601String(),
      'status': status,
    });
  } else {
    // 🔄 Atualiza o status caso o usuário tenha alterado (sem duplicar)
    await db.update(
      'dose_confirmada',
      {
        'status': status,
        'horarioConfirmacao': DateTime.now().toIso8601String(),
      },
      where:
          'medicamentoId = ? AND DATE(horarioConfirmacao) = DATE("now")',
      whereArgs: [medicamentoId],
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

  // ================= NOVO MÉTODO =================
  Future<void> marcarPendentesComoNaoTomados() async {
  final db = await database;
  final agora = DateTime.now().toIso8601String();

  // Busca medicamentos que já passaram do horário e ainda não foram marcados
  final pendentes = await db.query(
    'medicamentos',
    where:
        'dataHoraAgendamento < ? AND isTaken = 0 AND isIgnored = 0',
    whereArgs: [agora],
  );

  for (var med in pendentes) {
    final usuarioId = med['usuarioId'] ?? 0;

    // Marca o medicamento como pendente
    await db.update(
      'medicamentos',
      {'isPendente': 1},
      where: 'id = ?',
      whereArgs: [med['id']],
    );

    // Verifica se já existe um registro em dose_confirmada
    final existe = await db.query(
      'dose_confirmada',
      where: 'medicamentoId = ? AND status = ?',
      whereArgs: [med['id'], 'NÃO TOMADO'],
      limit: 1,
    );

    if (existe.isEmpty) {
      // Insere um novo registro de dose não tomada
      await db.insert('dose_confirmada', {
        'medicamentoId': med['id'],
        'usuarioId': usuarioId,
        'horarioConfirmacao': agora,
        'status': 'NÃO TOMADO',
      });
    }
  }
}


  // ================= DEBUG / FECHAR =================
  Future<void> debugListTables() async {
    final db = await database;
    final tables = await db
        .rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    print("🧩 Tabelas encontradas no banco: $tables");
  }

  Future close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  // Reinicialização do app
Future<void> resetDatabase() async {
  final db = await database; // usa o getter já definido lá em cima

  // Apaga os dados das tabelas
  await db.delete('dose_confirmada');
  await db.delete('tratamentos');
  await db.delete('medicamentos');
  await db.delete('usuarios');

  print("🧹 Todas as tabelas foram limpas com sucesso!");
}
}

