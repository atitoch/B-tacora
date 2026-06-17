import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/task.dart';
import '../models/daily_note.dart';

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
      version: 1,
      onCreate: _onCreate,
    );
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
        activo INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE habit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL,
        fecha TEXT NOT NULL,
        completado INTEGER NOT NULL DEFAULT 0,
        nota TEXT,
        FOREIGN KEY (habit_id) REFERENCES habits(id),
        UNIQUE(habit_id, fecha)
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        fecha TEXT NOT NULL,
        completada INTEGER NOT NULL DEFAULT 0
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
    );
    return rows.map(Habit.fromMap).toList();
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
    await d.delete('habits', where: 'id = ?', whereArgs: [id]);
    await d.delete('habit_logs', where: 'habit_id = ?', whereArgs: [id]);
  }

  // ─── HabitLogs ───────────────────────────────────────────────────────────

  Future<HabitLog?> getLog(int habitId, DateTime fecha) async {
    final d = await db;
    final key = _dateKey(fecha);
    final rows = await d.query(
      'habit_logs',
      where: 'habit_id = ? AND fecha = ?',
      whereArgs: [habitId, key],
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
      args = [habitId, _dateKey(desde)];
    }

    final rows = await d.query(
      'habit_logs',
      where: where,
      whereArgs: args,
      orderBy: 'fecha DESC',
    );
    return rows.map(HabitLog.fromMap).toList();
  }

  // ─── Tasks ───────────────────────────────────────────────────────────────

  Future<List<Task>> getTasksForDate(DateTime fecha) async {
    final d = await db;
    final rows = await d.query(
      'tasks',
      where: 'fecha = ?',
      whereArgs: [_dateKey(fecha)],
      orderBy: 'id ASC',
    );
    return rows.map(Task.fromMap).toList();
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
      whereArgs: [_dateKey(fecha)],
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
    final habits = await d.query('habits');
    final logs = await d.query('habit_logs');
    final tasks = await d.query('tasks');
    final notes = await d.query('daily_notes');

    return {
      'exported_at': DateTime.now().toIso8601String(),
      'version': 1,
      'habits': habits,
      'habit_logs': logs,
      'tasks': tasks,
      'daily_notes': notes,
    };
  }

  String exportToJson(Map<String, dynamic> data) =>
      const JsonEncoder.withIndent('  ').convert(data);

  // ─── Seed ────────────────────────────────────────────────────────────────

  Future<void> seedHabits(TimeOfDay horaDespertar) async {
    final horaEjercicio = const TimeOfDay(hour: 7, minute: 0);
    final horaIngles = const TimeOfDay(hour: 21, minute: 0);

    final seeds = [
      Habit(
        nombre: 'Hora de pie',
        tipoFrecuencia: FrecuenciaTipo.diario,
        horaObjetivo: horaDespertar,
      ),
      Habit(
        nombre: 'Inglés',
        tipoFrecuencia: FrecuenciaTipo.diasEspecificos,
        diasSemana: [1, 2, 3, 4], // Lun–Jue
        horaObjetivo: horaIngles,
      ),
      Habit(
        nombre: 'Ejercicio',
        tipoFrecuencia: FrecuenciaTipo.diasEspecificos,
        diasSemana: [1, 3, 6], // Lun, Mié, Sáb
        horaObjetivo: horaEjercicio,
      ),
      Habit(
        nombre: '3 comidas completas',
        tipoFrecuencia: FrecuenciaTipo.diario,
      ),
      Habit(
        nombre: 'Avanzar proyecto personal',
        tipoFrecuencia: FrecuenciaTipo.diario,
      ),
    ];

    for (final h in seeds) {
      await insertHabit(h);
    }
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
