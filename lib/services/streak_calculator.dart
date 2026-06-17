import '../models/habit.dart';
import '../models/habit_log.dart';
import '../utils/date_utils.dart' as du;

class StreakCalculator {
  static const int _maxDaysBack = 365;

  static int rachaActual(Habit habit, List<HabitLog> logs) {
    final logMap = {for (final l in logs) du.dateKey(l.fecha): l};
    int racha = 0;
    var dia = DateTime.now();

    for (int i = 0; i < _maxDaysBack; i++) {
      if (!habit.tocaHoy(dia)) {
        dia = dia.subtract(const Duration(days: 1));
        continue;
      }
      final log = logMap[du.dateKey(dia)];
      if (log == null || !log.completado) break;
      racha++;
      dia = dia.subtract(const Duration(days: 1));
    }

    return racha;
  }

  /// Fallos consecutivos contados hasta ayer (hoy todavía puede completarse).
  static int rachaFallos(Habit habit, List<HabitLog> logs) {
    final logMap = {for (final l in logs) du.dateKey(l.fecha): l};
    int fallos = 0;
    var dia = DateTime.now().subtract(const Duration(days: 1));

    for (int i = 0; i < _maxDaysBack; i++) {
      if (!habit.tocaHoy(dia)) {
        dia = dia.subtract(const Duration(days: 1));
        continue;
      }
      final log = logMap[du.dateKey(dia)];
      if (log != null && log.completado) break;
      fallos++;
      if (fallos >= 14) break;
      dia = dia.subtract(const Duration(days: 1));
    }

    return fallos;
  }

  static List<bool?> historial(Habit habit, List<HabitLog> logs, int dias) {
    final logMap = {for (final l in logs) du.dateKey(l.fecha): l};
    final result = <bool?>[];
    for (int i = dias - 1; i >= 0; i--) {
      final dia = DateTime.now().subtract(Duration(days: i));
      if (!habit.tocaHoy(dia)) {
        result.add(null);
      } else {
        final log = logMap[du.dateKey(dia)];
        result.add(log?.completado);
      }
    }
    return result;
  }
}
