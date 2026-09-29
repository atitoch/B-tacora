import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/task.dart';
import '../models/daily_note.dart';
import '../utils/date_utils.dart' as du;

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;
  DatabaseService._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'btacora.db'),
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE habits ADD COLUMN fecha_creacion TEXT',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE habits ADD COLUMN orden INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE tasks ADD COLUMN orden INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE tasks ADD COLUMN prioridad INTEGER NOT NULL DEFAULT 0');
      // Inicializar orden = id para preservar el orden existente
      await db.execute('UPDATE habits SET orden = id');
      await db.execute('UPDATE tasks SET orden = id');
    }
    if (oldVersion < 4) {
      // Hora objetivo opcional para tareas (habilita notificaciones).
      await db.execute('ALTER TABLE tasks ADD COLUMN hora_h INTEGER');
      await db.execute('ALTER TABLE tasks ADD COLUMN hora_m INTEGER');
      // Snapshot de la hora objetivo al registrar un hábito: preserva la hora
      // histórica aunque luego se edite el hábito.
      await db.execute('ALTER TABLE habit_logs ADD COLUMN hora_h INTEGER');
      await db.execute('ALTER TABLE habit_logs ADD COLUMN hora_m INTEGER');
    }
    if (oldVersion < 5) {
      // Tareas persistentes: se arrastran a días siguientes hasta completarse.
      // Las tareas existentes quedan como NO persistentes para no inundar el
      // día de hoy con pendientes antiguas.
      await db.execute(
          'ALTER TABLE tasks ADD COLUMN persistente INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE tasks ADD COLUMN fecha_completada TEXT');
      await db.execute(
          'UPDATE tasks SET fecha_completada = fecha WHERE completada = 1');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        tipo_frecuencia INTEGER NOT NULL,
        dias_semana TEXT,
        hora_h INTEGER,
        hora_m INTEGER,
        activo INTEGER NOT NULL DEFAULT 1,
        fecha_creacion TEXT,
        orden INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL,
        fecha TEXT NOT NULL,
        completado INTEGER NOT NULL DEFAULT 0,
        nota TEXT,
        hora_h INTEGER,
        hora_m INTEGER,
        FOREIGN KEY (habit_id) REFERENCES habits(id),
        UNIQUE(habit_id, fecha)
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        fecha TEXT NOT NULL,
        completada INTEGER NOT NULL DEFAULT 0,
        prioridad INTEGER NOT NULL DEFAULT 0,
        orden INTEGER NOT NULL DEFAULT 0,
        hora_h INTEGER,
        hora_m INTEGER,
        persistente INTEGER NOT NULL DEFAULT 0,
        fecha_completada TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT NOT NULL UNIQUE,
        texto TEXT NOT NULL,
        nivel_energia INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE prefs (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ─── Prefs ───────────────────────────────────────────────────────────────

  Future<String?> getPref(String key) async {
    final d = await db;
    final rows = await d.query('prefs', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setPref(String key, String value) async {
    final d = await db;
    await d.insert(
      'prefs',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ─── Habits ──────────────────────────────────────────────────────────────

  Future<List<Habit>> getHabits({bool soloActivos = true}) async {
    final d = await db;
    final rows = await d.query(
      'habits',
      where: soloActivos ? 'activo = 1' : null,
      orderBy: 'orden ASC, id ASC',
    );
    return rows.map(Habit.fromMap).toList();
  }

  Future<void> saveHabitOrder(List<Habit> habits) async {
    final d = await db;
    final batch = d.batch();
    for (var i = 0; i < habits.length; i++) {
      batch.update('habits', {'orden': i},
          where: 'id = ?', whereArgs: [habits[i].id]);
    }
    await batch.commit(noResult: true);
  }

  Future<int> insertHabit(Habit h) async {
    final d = await db;
    return d.insert('habits', h.toMap());
  }

  Future<void> updateHabit(Habit h) async {
    final d = await db;
    await d.update('habits', h.toMap(), where: 'id = ?', whereArgs: [h.id]);
  }

  Future<void> deleteHabit(int id) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('habits', where: 'id = ?', whereArgs: [id]);
      await txn.delete('habit_logs', where: 'habit_id = ?', whereArgs: [id]);
    });
  }

  // ─── HabitLogs ───────────────────────────────────────────────────────────

  Future<HabitLog?> getLog(int habitId, DateTime fecha) async {
    final d = await db;
    final rows = await d.query(
      'habit_logs',
      where: 'habit_id = ? AND fecha = ?',
      whereArgs: [habitId, du.dateKey(fecha)],
    );
    return rows.isEmpty ? null : HabitLog.fromMap(rows.first);
  }

  Future<void> upsertLog(HabitLog log) async {
    final d = await db;
    await d.insert(
      'habit_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<HabitLog>> getLogsForHabit(int habitId,
      {int? ultimosDias}) async {
    final d = await db;
    String? where = 'habit_id = ?';
    List<dynamic> args = [habitId];

    if (ultimosDias != null) {
      final desde = DateTime.now().subtract(Duration(days: ultimosDias));
      where = 'habit_id = ? AND fecha >= ?';
      args = [habitId, du.dateKey(desde)];
    }

    final rows = await d.query(
      'habit_logs',
      where: where,
      whereArgs: args,
      orderBy: 'fecha DESC',
    );
    return rows.map(HabitLog.fromMap).toList();
  }

  /// Carga los logs de los últimos [ultimosDias] días para todos los habitIds
  /// en una sola query, devolviendo un mapa habitId → lista de logs.
  Future<Map<int, List<HabitLog>>> getLogsForAllHabits(
    List<int> habitIds, {
    required int ultimosDias,
  }) async {
    if (habitIds.isEmpty) return {};
    final d = await db;
    final desde = du.dateKey(
        DateTime.now().subtract(Duration(days: ultimosDias)));
    final placeholders = List.filled(habitIds.length, '?').join(',');
    final rows = await d.rawQuery(
      'SELECT * FROM habit_logs '
      'WHERE habit_id IN ($placeholders) AND fecha >= ? '
      'ORDER BY fecha DESC',
      [...habitIds, desde],
    );
    final result = <int, List<HabitLog>>{
      for (final id in habitIds) id: [],
    };
    for (final row in rows) {
      final log = HabitLog.fromMap(row);
      result[log.habitId]!.add(log);
    }
    return result;
  }

  // ─── Tasks ───────────────────────────────────────────────────────────────

  /// Tareas visibles en [fecha]: las creadas ese día, más las persistentes de
  /// días anteriores que seguían pendientes ese día (pendientes todavía, o
  /// completadas en [fecha] o después).
  Future<List<Task>> getTasksForDate(DateTime fecha) async {
    final d = await db;
    final key = du.dateKey(fecha);
    final rows = await d.query(
      'tasks',
      where: 'fecha = ? OR (persistente = 1 AND fecha < ? AND '
          '(completada = 0 OR fecha_completada IS NULL OR fecha_completada >= ?))',
      whereArgs: [key, key, key],
      orderBy: 'orden ASC, id ASC',
    );
    return rows.map(Task.fromMap).toList();
  }

  /// Tareas con hora objetivo y pendientes: las de hoy en adelante y las
  /// persistentes de días anteriores (que siguen recordándose cada día).
  /// Usado al iniciar la app para (re)programar sus notificaciones.
  Future<List<Task>> getUpcomingTasksWithTime() async {
    final d = await db;
    final hoy = du.dateKey(DateTime.now());
    final rows = await d.query(
      'tasks',
      where: '(fecha >= ? OR persistente = 1) AND hora_h IS NOT NULL '
          'AND completada = 0',
      whereArgs: [hoy],
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<void> saveTaskOrder(List<Task> tasks) async {
    final d = await db;
    final batch = d.batch();
    for (var i = 0; i < tasks.length; i++) {
      batch.update('tasks', {'orden': i},
          where: 'id = ?', whereArgs: [tasks[i].id]);
    }
    await batch.commit(noResult: true);
  }

  Future<int> insertTask(Task t) async {
    final d = await db;
    return d.insert('tasks', t.toMap());
  }

  Future<void> updateTask(Task t) async {
    final d = await db;
    await d.update('tasks', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
  }

  Future<void> deleteTask(int id) async {
    final d = await db;
    await d.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // ─── DailyNote ───────────────────────────────────────────────────────────

  Future<DailyNote?> getNoteForDate(DateTime fecha) async {
    final d = await db;
    final rows = await d.query(
      'daily_notes',
      where: 'fecha = ?',
      whereArgs: [du.dateKey(fecha)],
    );
    return rows.isEmpty ? null : DailyNote.fromMap(rows.first);
  }

  Future<void> upsertNote(DailyNote note) async {
    final d = await db;
    await d.insert(
      'daily_notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ─── Export ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> exportAll() async {
    final d = await db;
    // Transacción de solo-lectura: snapshot consistente de todas las tablas.
    return d.transaction((txn) async {
      final habits = await txn.query('habits');
      final logs = await txn.query('habit_logs');
      final tasks = await txn.query('tasks');
      final notes = await txn.query('daily_notes');
      return {
        'exported_at': DateTime.now().toIso8601String(),
        'version': 1,
        'habits': habits,
        'habit_logs': logs,
        'tasks': tasks,
        'daily_notes': notes,
      };
    });
  }

  String exportToJson(Map<String, dynamic> data) =>
      const JsonEncoder.withIndent('  ').convert(data);

  // ─── Seed ────────────────────────────────────────────────────────────────

  /// Inserta los hábitos semilla dentro de una transacción atómica.
  /// Si el proceso muere a la mitad, ningún hábito queda a medias.
  Future<void> seedHabits(TimeOfDay horaDespertar) async {
    final horaEjercicio = const TimeOfDay(hour: 7, minute: 0);
    final horaIngles = const TimeOfDay(hour: 21, minute: 0);

    final hoy = DateTime.now();
    final seeds = [
      Habit(
        nombre: 'Hora de pie',
        tipoFrecuencia: FrecuenciaTipo.diario,
        horaObjetivo: horaDespertar,
        fechaCreacion: hoy,
      ),
      Habit(
        nombre: 'Inglés',
        tipoFrecuencia: FrecuenciaTipo.diasEspecificos,
        diasSemana: [1, 2, 3, 4],
        horaObjetivo: horaIngles,
        fechaCreacion: hoy,
      ),
      Habit(
        nombre: 'Ejercicio',
        tipoFrecuencia: FrecuenciaTipo.diasEspecificos,
        diasSemana: [1, 3, 6],
        horaObjetivo: horaEjercicio,
        fechaCreacion: hoy,
      ),
      Habit(
        nombre: '3 comidas completas',
        tipoFrecuencia: FrecuenciaTipo.diario,
        fechaCreacion: hoy,
      ),
      Habit(
        nombre: 'Avanzar proyecto personal',
        tipoFrecuencia: FrecuenciaTipo.diario,
        fechaCreacion: hoy,
      ),
    ];

    final d = await db;
    // Seed + onboarding_done en una sola transacción: si el proceso muere
    // a la mitad, ambos se revierten y el onboarding vuelve a correr limpio.
    await d.transaction((txn) async {
      final existing = await txn.query('habits', limit: 1);
      // Solo insertar seeds si no existen (guard contra crash-retry).
      // onboarding_done se escribe SIEMPRE dentro de la misma transacción
      // para corregir el caso en que hay hábitos pero falta el pref.
      if (existing.isEmpty) {
        for (final h in seeds) {
          await txn.insert('habits', h.toMap());
        }
      }
      await txn.insert(
        'prefs',
        {'key': 'onboarding_done', 'value': '1'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }
}
