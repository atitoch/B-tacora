import 'package:flutter/material.dart';
import '../utils/date_utils.dart' as du;

class HabitLog {
  final int? id;
  final int habitId;
  final DateTime fecha;
  final bool completado;
  final String? nota;

  // Snapshot de la hora objetivo del hábito en el momento del registro.
  // Editar la hora del hábito más tarde NO altera este valor: los registros
  // pasados conservan la hora con la que se crearon.
  final TimeOfDay? horaObjetivo;

  HabitLog({
    this.id,
    required this.habitId,
    required this.fecha,
    required this.completado,
    this.nota,
    this.horaObjetivo,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'habit_id': habitId,
      'fecha': du.dateKey(fecha),
      'completado': completado ? 1 : 0,
      'nota': nota,
      'hora_h': horaObjetivo?.hour,
      'hora_m': horaObjetivo?.minute,
    };
  }

  factory HabitLog.fromMap(Map<String, dynamic> m) {
    return HabitLog(
      id: m['id'] as int?,
      habitId: m['habit_id'] as int,
      fecha: DateTime.parse(m['fecha'] as String),
      completado: (m['completado'] as int) == 1,
      nota: m['nota'] as String?,
      horaObjetivo: (m['hora_h'] != null && m['hora_m'] != null)
          ? TimeOfDay(hour: m['hora_h'] as int, minute: m['hora_m'] as int)
          : null,
    );
  }

  HabitLog copyWith({bool? completado, String? nota, TimeOfDay? horaObjetivo}) {
    return HabitLog(
      id: id,
      habitId: habitId,
      fecha: fecha,
      completado: completado ?? this.completado,
      nota: nota ?? this.nota,
      horaObjetivo: horaObjetivo ?? this.horaObjetivo,
    );
  }
}
