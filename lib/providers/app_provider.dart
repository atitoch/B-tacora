import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/task.dart';
import '../models/daily_note.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/streak_calculator.dart';

class AppProvider extends ChangeNotifier {
  final _db = DatabaseService();
  final _notif = NotificationService();

  List<Habit> _habits = [];
  List<Task> _tasks = [];
  DailyNote? _dailyNote;
  DateTime _selectedDate = DateTime.now();

  // Logs cargados para la fecha seleccionada: habitId -> HabitLog?
  final Map<int, HabitLog?> _logsHoy = {};
  // Logs históricos: habitId -> lista
  final Map<int, List<HabitLog>> _logsHistorico = {};

  List<Habit> get habits => _habits;
  List<Task> get tasks => _tasks;
  DailyNote? get dailyNote => _dailyNote;
  DateTime get selectedDate => _selectedDate;

  List<Habit> get habitsDeLaFecha =>
      _habits.where((h) => h.tocaHoy(_selectedDate)).toList();

  HabitLog? logDeHoy(int habitId) => _logsHoy[habitId];

  int rachaActual(Habit habit) {
    final logs = _logsHistorico[habit.id] ?? [];
    return StreakCalculator.rachaActual(habit, logs);
  }

  int rachaFallos(Habit habit) {
    final logs = _logsHistorico[habit.id] ?? [];
    return StreakCalculator.rachaFallos(habit, logs);
  }

  List<bool?> historial14(Habit habit) {
    final logs = _logsHistorico[habit.id] ?? [];
    return StreakCalculator.historial(habit, logs, 14);
  }

  Future<void> initialize() async {
    await _notif.init();
    await _loadHabits();
    await _loadTasksAndNote();
  }

  Future<void> _loadHabits() async {
    _habits = await _db.getHabits();
    _logsHoy.clear();
    _logsHistorico.clear();

    for (final h in _habits) {
      final log = await _db.getLog(h.id!, _selectedDate);
      _logsHoy[h.id!] = log;

      final historicos = await _db.getLogsForHabit(h.id!, ultimosDias: 60);
      _logsHistorico[h.id!] = historicos;
    }
    notifyListeners();
  }

  Future<void> _loadTasksAndNote() async {
    _tasks = await _db.getTasksForDate(_selectedDate);
    _dailyNote = await _db.getNoteForDate(_selectedDate);
    notifyListeners();
  }

  Future<void> toggleHabit(Habit habit, bool completado) async {
    final log = HabitLog(
      id: _logsHoy[habit.id]?.id,
      habitId: habit.id!,
      fecha: _selectedDate,
      completado: completado,
    );
    await _db.upsertLog(log);
    _logsHoy[habit.id!] = log;

    final historicos = await _db.getLogsForHabit(habit.id!, ultimosDias: 60);
    _logsHistorico[habit.id!] = historicos;

    // Reprogramar notificación con nuevo estado de fallos
    final fallos = StreakCalculator.rachaFallos(
      habit,
      _logsHistorico[habit.id!] ?? [],
    );
    await _notif.scheduleHabitNotification(
      habit: habit,
      fallosConsecutivos: fallos,
    );

    notifyListeners();
  }

  Future<void> addHabit(Habit habit) async {
    final id = await _db.insertHabit(habit);
    final h = habit.copyWith(id: id);
    _habits.add(h);
    _logsHoy[id] = null;
    _logsHistorico[id] = [];
    await _notif.scheduleHabitNotification(habit: h, fallosConsecutivos: 0);
    notifyListeners();
  }

  Future<void> updateHabit(Habit habit) async {
    await _db.updateHabit(habit);
    final idx = _habits.indexWhere((h) => h.id == habit.id);
    if (idx != -1) _habits[idx] = habit;
    await _notif.cancelHabitNotifications(habit.id!);
    final fallos = rachaFallos(habit);
    await _notif.scheduleHabitNotification(
        habit: habit, fallosConsecutivos: fallos);
    notifyListeners();
  }

  Future<void> deleteHabit(int id) async {
    await _db.deleteHabit(id);
    await _notif.cancelHabitNotifications(id);
    _habits.removeWhere((h) => h.id == id);
    _logsHoy.remove(id);
    _logsHistorico.remove(id);
    notifyListeners();
  }

  Future<void> addTask(String nombre) async {
    final t = Task(nombre: nombre, fecha: _selectedDate);
    final id = await _db.insertTask(t);
    _tasks.add(Task(id: id, nombre: nombre, fecha: _selectedDate));
    notifyListeners();
  }

  Future<void> toggleTask(Task task) async {
    final updated = task.copyWith(completada: !task.completada);
    await _db.updateTask(updated);
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx != -1) _tasks[idx] = updated;
    notifyListeners();
  }

  Future<void> deleteTask(int id) async {
    await _db.deleteTask(id);
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  Future<void> saveDailyNote(String texto, int? nivelEnergia) async {
    final note = DailyNote(
      id: _dailyNote?.id,
      fecha: _selectedDate,
      texto: texto,
      nivelEnergia: nivelEnergia,
    );
    await _db.upsertNote(note);
    _dailyNote = note;
    notifyListeners();
  }

  Future<void> selectDate(DateTime date) async {
    _selectedDate = date;
    await _loadHabits();
    await _loadTasksAndNote();
  }

  Future<String> exportJson() async {
    final data = await _db.exportAll();
    return _db.exportToJson(data);
  }

  Future<bool> isFirstRun() async {
    final v = await _db.getPref('onboarding_done');
    return v == null;
  }

  Future<void> completeOnboarding(TimeOfDay horaDespertar) async {
    await _db.seedHabits(horaDespertar);
    await _db.setPref('onboarding_done', '1');
    await _db.setPref(
        'hora_despertar', '${horaDespertar.hour}:${horaDespertar.minute}');
    await _loadHabits();

    // Programar notificaciones para todos los hábitos semilla
    for (final h in _habits) {
      await _notif.scheduleHabitNotification(habit: h, fallosConsecutivos: 0);
    }
  }
}
