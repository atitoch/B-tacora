import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/task.dart' show Task, Prioridad;
import '../models/daily_note.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/streak_calculator.dart';
import '../utils/date_utils.dart' as du;

class AppProvider extends ChangeNotifier {
  final _db = DatabaseService();
  final _notif = NotificationService();

  List<Habit> _habits = [];
  List<Task> _tasks = [];
  DailyNote? _dailyNote;

  // Normalizado a medianoche para evitar desfases de hora/DST en comparaciones.
  DateTime _selectedDate = _midnight(DateTime.now());

  // Logs históricos: habitId → lista (últimos 365 días, alineado con StreakCalculator.maxDaysBack)
  final Map<int, List<HabitLog>> _logsHistorico = {};

  // Guard contra doble-tap: habitIds cuyo toggle está en vuelo.
  final Set<int> _toggling = {};

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  List<Habit> get habits => _habits;
  List<Task> get tasks => _tasks;
  DailyNote? get dailyNote => _dailyNote;
  DateTime get selectedDate => _selectedDate;

  List<Habit> get habitsDeLaFecha =>
      _habits.where((h) => h.tocaHoy(_selectedDate)).toList();

  HabitLog? logDeHoy(int habitId) {
    final key = du.dateKey(_selectedDate);
    return _logsHistorico[habitId]
        ?.where((l) => du.dateKey(l.fecha) == key)
        .firstOrNull;
  }

  int rachaActual(Habit habit) {
    return StreakCalculator.rachaActual(
        habit, _logsHistorico[habit.id] ?? [], _selectedDate);
  }

  int rachaFallos(Habit habit) {
    return StreakCalculator.rachaFallos(
        habit, _logsHistorico[habit.id] ?? [], _selectedDate);
  }

  List<bool?> historial14(Habit habit) {
    return StreakCalculator.historial(
        habit, _logsHistorico[habit.id] ?? [], 14, _selectedDate);
  }

  Future<void> initialize() async {
    try {
      await _notif.init();
    } catch (_) {}
    await _loadHabits();
    await _loadTasksAndNote();
    try {
      await Future.wait([
        for (final h in _habits)
          _notif.scheduleHabitNotification(
            habit: h,
            fallosConsecutivos: rachaFallos(h),
          ),
      ]);
    } catch (_) {}
  }

  /// Refresca la fecha de referencia cuando la app vuelve a foreground.
  /// Evita que la app muestre "ayer" si estuvo abierta de noche.
  Future<void> refreshDate() async {
    final today = _midnight(DateTime.now());
    if (!du.isSameDay(_selectedDate, today)) {
      _selectedDate = today;
      await _loadTasksAndNote();
    }
  }

  Future<void> _loadHabits() async {
    _habits = await _db.getHabits();
    _logsHistorico.clear();

    if (_habits.isNotEmpty) {
      final ids = _habits.map((h) => h.id!).toList();
      final batch = await _db.getLogsForAllHabits(
          ids, ultimosDias: StreakCalculator.maxDaysBack);
      _logsHistorico.addAll(batch);
    }

    notifyListeners();
  }

  Future<void> _loadTasksAndNote() async {
    _tasks = await _db.getTasksForDate(_selectedDate);
    _dailyNote = await _db.getNoteForDate(_selectedDate);
    notifyListeners();
  }

  Future<void> toggleHabit(Habit habit, bool completado) async {
    final id = habit.id!;
    // Guard contra doble-tap concurrente sobre el mismo hábito.
    if (_toggling.contains(id)) return;
    _toggling.add(id);

    try {
      final existing = logDeHoy(id);
      final log = HabitLog(
        id: existing?.id,
        habitId: id,
        fecha: _selectedDate,
        completado: completado,
        nota: existing?.nota,
      );
      await _db.upsertLog(log);

      final list = _logsHistorico[id] ??= [];
      final idx = list.indexWhere((l) => du.isSameDay(l.fecha, _selectedDate));
      if (idx >= 0) {
        list[idx] = log;
      } else {
        list.insert(0, log);
      }

      final fallos = StreakCalculator.rachaFallos(
        habit,
        _logsHistorico[id] ?? [],
        _selectedDate,
      );
      try {
        await _notif.scheduleHabitNotification(
          habit: habit,
          fallosConsecutivos: fallos,
        );
      } catch (_) {}

      notifyListeners();
    } finally {
      _toggling.remove(id);
    }
  }

  Future<void> addHabit(Habit habit) async {
    final today = _midnight(DateTime.now());
    final habitConFecha = habit.fechaCreacion == null
        ? habit.copyWith(fechaCreacion: today) // normalizado a medianoche
        : habit;
    final id = await _db.insertHabit(habitConFecha);
    final h = habitConFecha.copyWith(id: id);
    _habits.add(h);
    _logsHistorico[id] = [];
    try {
      await _notif.scheduleHabitNotification(habit: h, fallosConsecutivos: 0);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> updateHabit(Habit habit) async {
    await _db.updateHabit(habit);
    final idx = _habits.indexWhere((h) => h.id == habit.id);
    if (idx != -1) _habits[idx] = habit;
    final fallos = rachaFallos(habit);
    try {
      await _notif.scheduleHabitNotification(
          habit: habit, fallosConsecutivos: fallos);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> reorderHabits(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final visible = habitsDeLaFecha;
    final fromId = visible[oldIndex].id!;
    final toId = visible[newIndex].id!;
    final fromGlobal = _habits.indexWhere((h) => h.id == fromId);
    final toGlobal = _habits.indexWhere((h) => h.id == toId);
    final item = _habits.removeAt(fromGlobal);
    _habits.insert(toGlobal, item);
    for (var i = 0; i < _habits.length; i++) {
      _habits[i] = _habits[i].copyWith(orden: i);
    }
    await _db.saveHabitOrder(_habits);
    notifyListeners();
  }

  Future<void> deleteHabit(int id) async {
    await _db.deleteHabit(id);
    await _notif.cancelHabitNotifications(id);
    _habits.removeWhere((h) => h.id == id);
    _logsHistorico.remove(id);
    notifyListeners();
  }

  Future<void> addTask(String nombre) async {
    final t = Task(nombre: nombre, fecha: _selectedDate);
    final id = await _db.insertTask(t);
    _tasks.add(t.copyWith(id: id));
    notifyListeners();
  }

  Future<void> toggleTask(Task task) async {
    final updated = task.copyWith(completada: !task.completada);
    await _db.updateTask(updated);
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx != -1) _tasks[idx] = updated;
    notifyListeners();
  }

  Future<void> renameTask(Task task, String nuevoNombre) async {
    final updated = task.copyWith(nombre: nuevoNombre);
    await _db.updateTask(updated);
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx != -1) _tasks[idx] = updated;
    notifyListeners();
  }

  Future<void> setTaskPriority(Task task, Prioridad prioridad) async {
    final updated = task.copyWith(prioridad: prioridad);
    await _db.updateTask(updated);
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx != -1) _tasks[idx] = updated;
    notifyListeners();
  }

  Future<void> reorderTasks(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _tasks.removeAt(oldIndex);
    _tasks.insert(newIndex, item);
    for (var i = 0; i < _tasks.length; i++) {
      _tasks[i] = _tasks[i].copyWith(orden: i);
    }
    await _db.saveTaskOrder(_tasks);
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
    _selectedDate = _midnight(date); // siempre normalizado a medianoche
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
    await _db.setPref(
        'hora_despertar', '${horaDespertar.hour}:${horaDespertar.minute}');
    await _loadHabits();

    try {
      await Future.wait([
        for (final h in _habits)
          _notif.scheduleHabitNotification(habit: h, fallosConsecutivos: 0),
      ]);
    } catch (_) {}
  }
}
