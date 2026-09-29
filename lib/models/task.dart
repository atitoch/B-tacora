import 'package:flutter/material.dart';
import '../utils/date_utils.dart' as du;

enum Prioridad { ninguna, alta, media, baja }

class Task {
  final int? id;
  final String nombre;
  final DateTime fecha;
  final bool completada;
  final Prioridad prioridad;
  final int orden;
  final TimeOfDay? horaObjetivo;

  /// Si es true, la tarea se arrastra a los días siguientes mientras siga
  /// pendiente (aparece en cada día desde [fecha] hasta que se completa).
  final bool persistente;

  /// Día en que se marcó como completada (null si está pendiente).
  final DateTime? fechaCompletada;

  Task({
    this.id,
    required this.nombre,
    required this.fecha,
    this.completada = false,
    this.prioridad = Prioridad.ninguna,
    this.orden = 0,
    this.horaObjetivo,
    this.persistente = false,
    this.fechaCompletada,
  });

  /// Estado de la tarea visto desde el día [dia]: una tarea persistente que se
  /// completó después de [dia] seguía pendiente ese día.
  bool completadaEn(DateTime dia) {
    if (!completada) return false;
    final fc = fechaCompletada;
    return fc == null || du.dateKey(fc).compareTo(du.dateKey(dia)) <= 0;
  }

  /// Días que lleva arrastrándose al día [dia] (0 si es su día original).
  int diasArrastrada(DateTime dia) {
    final origen = DateTime(fecha.year, fecha.month, fecha.day);
    final d = DateTime(dia.year, dia.month, dia.day);
    // Diferencia en días calendario (UTC evita desfases de DST).
    final diff = DateTime.utc(d.year, d.month, d.day)
        .difference(DateTime.utc(origen.year, origen.month, origen.day))
        .inDays;
    return diff > 0 ? diff : 0;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'fecha': du.dateKey(fecha),
      'completada': completada ? 1 : 0,
      'prioridad': prioridad.index,
      'orden': orden,
      'hora_h': horaObjetivo?.hour,
      'hora_m': horaObjetivo?.minute,
      'persistente': persistente ? 1 : 0,
      'fecha_completada':
          fechaCompletada != null ? du.dateKey(fechaCompletada!) : null,
    };
  }

  factory Task.fromMap(Map<String, dynamic> m) {
    return Task(
      id: m['id'] as int?,
      nombre: m['nombre'] as String,
      fecha: DateTime.parse(m['fecha'] as String),
      completada: (m['completada'] as int) == 1,
      prioridad: Prioridad.values[(m['prioridad'] as int?) ?? 0],
      orden: (m['orden'] as int?) ?? 0,
      horaObjetivo: (m['hora_h'] != null && m['hora_m'] != null)
          ? TimeOfDay(hour: m['hora_h'] as int, minute: m['hora_m'] as int)
          : null,
      persistente: (m['persistente'] as int? ?? 0) == 1,
      fechaCompletada: m['fecha_completada'] != null
          ? DateTime.parse(m['fecha_completada'] as String)
          : null,
    );
  }

  Task copyWith({
    int? id,
    bool? completada,
    String? nombre,
    Prioridad? prioridad,
    int? orden,
    TimeOfDay? horaObjetivo,
    bool clearHora = false,
    bool? persistente,
    DateTime? fechaCompletada,
    bool clearFechaCompletada = false,
  }) {
    return Task(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      fecha: fecha,
      completada: completada ?? this.completada,
      prioridad: prioridad ?? this.prioridad,
      orden: orden ?? this.orden,
      horaObjetivo: clearHora ? null : (horaObjetivo ?? this.horaObjetivo),
      persistente: persistente ?? this.persistente,
      fechaCompletada: clearFechaCompletada
          ? null
          : (fechaCompletada ?? this.fechaCompletada),
    );
  }
}
