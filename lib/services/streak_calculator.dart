import '../models/habit.dart';
import '../models/habit_log.dart';

class StreakCalculator {
  /// Calcula días consecutivos completados hasta hoy (hacia atrás).
  static int rachaActual(Habit habit, List<HabitLog> logs) {
    final logMap = {for (final l in logs) _dateKey(l.fecha): l};
    int racha = 0;
    var dia = DateTime.now();

    while (true) {
      if (!habit.tocaHoy(dia)) {
        dia = dia.subtract(const Duration(days: 1));
        continue;
      }
      final log = logMap[_dateKey(dia)];
      if (log == null || !log.completado) break;
      racha++;
      dia = dia.subtract(const Duration(days: 1));
    }

    return racha;
  }

  /// Días consecutivos fallados hasta ayer (no cuenta hoy — aún puede completar).
  static int rachaFallos(Habit habit, List<HabitLog> logs) {
    final logMap = {for (final l in logs) _dateKey(l.fecha): l};
    int fallos = 0;
    var dia = DateTime.now().subtract(const Duration(days: 1));

    while (true) {
      if (!habit.tocaHoy(dia)) {
        dia = dia.subtract(const Duration(days: 1));
        continue;
      }
      final log = logMap[_dateKey(dia)];
      // No registrado = fallo implícito
      if (log != null && log.completado) break;
      fallos++;
      if (fallos >= 14) break; // límite de búsqueda hacia atrás
      dia = dia.subtract(const Duration(days: 1));
    }

    return fallos;
  }

  /// Historial de los últimos [dias] días: lista de bool? (null = no aplica ese día)
  static List<bool?> historial(Habit habit, List<HabitLog> logs, int dias) {
    final logMap = {for (final l in logs) _dateKey(l.fecha): l};
    final result = <bool?>[];
    for (int i = dias - 1; i >= 0; i--) {
      final dia = DateTime.now().subtract(Duration(days: i));
      if (!habit.tocaHoy(dia)) {
        result.add(null);
      } else {
        final log = logMap[_dateKey(dia)];
        result.add(log?.completado);
      }
    }
    return result;
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
