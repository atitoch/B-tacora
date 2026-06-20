import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../utils/date_utils.dart' as du;

/// Estado de un día en el historial: si aplicaba/cumplió y la hora objetivo
/// con la que se registró (snapshot histórico).
typedef DiaHistorial = ({bool? estado, TimeOfDay? hora});

class StreakCalculator {
  // Público para que app_provider cargue exactamente la misma ventana de logs.
  static const int maxDaysBack = 365;

  static int rachaActual(
      Habit habit, List<HabitLog> logs, DateTime referenceDate) {
    final logMap = {for (final l in logs) du.dateKey(l.fecha): l};
    int racha = 0;
    var dia = referenceDate;

    for (int i = 0; i < maxDaysBack; i++) {
      if (!habit.tocaHoy(dia)) {
        dia = dia.subtract(const Duration(days: 1));
        continue;
      }
      final log = logMap[du.dateKey(dia)];
      if (log == null || !log.completado) {
        // La fecha de referencia todavía puede completarse — no rompe la racha.
        if (du.isSameDay(dia, referenceDate)) {
          dia = dia.subtract(const Duration(days: 1));
          continue;
        }
        break;
      }
      racha++;
      dia = dia.subtract(const Duration(days: 1));
    }

    return racha;
  }

  /// Fallos consecutivos contados hasta el día anterior a [referenceDate].
  static int rachaFallos(
      Habit habit, List<HabitLog> logs, DateTime referenceDate) {
    final logMap = {for (final l in logs) du.dateKey(l.fecha): l};
    int fallos = 0;
    var dia = referenceDate.subtract(const Duration(days: 1));

    for (int i = 0; i < maxDaysBack; i++) {
      if (!habit.tocaHoy(dia)) {
        dia = dia.subtract(const Duration(days: 1));
        continue;
      }
      // No contar días anteriores a la creación del hábito.
      if (habit.fechaCreacion != null &&
          dia.isBefore(habit.fechaCreacion!)) {
        break;
      }
      final log = logMap[du.dateKey(dia)];
      if (log != null && log.completado) break;
      fallos++;
      if (fallos >= 14) break;
      dia = dia.subtract(const Duration(days: 1));
    }

    return fallos;
  }

  static List<bool?> historial(
      Habit habit, List<HabitLog> logs, int dias, DateTime referenceDate) {
    final logMap = {for (final l in logs) du.dateKey(l.fecha): l};
    final result = <bool?>[];
    for (int i = dias - 1; i >= 0; i--) {
      final dia = referenceDate.subtract(Duration(days: i));
      // Días anteriores a la creación: no aplicable.
      if (habit.fechaCreacion != null && dia.isBefore(habit.fechaCreacion!)) {
        result.add(null);
        continue;
      }
      if (!habit.tocaHoy(dia)) {
        result.add(null);
      } else {
        final log = logMap[du.dateKey(dia)];
        result.add(du.isSameDay(dia, referenceDate)
            ? log?.completado
            : (log?.completado ?? false));
      }
    }
    return result;
  }

  /// Igual que [historial] pero incluye la hora objetivo registrada (snapshot)
  /// de cada día, para mostrar en el historial sin alterarla al editar el hábito.
  static List<DiaHistorial> historialDetalle(
      Habit habit, List<HabitLog> logs, int dias, DateTime referenceDate) {
    final logMap = {for (final l in logs) du.dateKey(l.fecha): l};
    final result = <DiaHistorial>[];
    for (int i = dias - 1; i >= 0; i--) {
      final dia = referenceDate.subtract(Duration(days: i));
      if (habit.fechaCreacion != null && dia.isBefore(habit.fechaCreacion!)) {
        result.add((estado: null, hora: null));
        continue;
      }
      if (!habit.tocaHoy(dia)) {
        result.add((estado: null, hora: null));
        continue;
      }
      final log = logMap[du.dateKey(dia)];
      final estado = du.isSameDay(dia, referenceDate)
          ? log?.completado
          : (log?.completado ?? false);
      result.add((estado: estado, hora: log?.horaObjetivo));
    }
    return result;
  }
}
