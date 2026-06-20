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

  Task({
    this.id,
    required this.nombre,
    required this.fecha,
    this.completada = false,
    this.prioridad = Prioridad.ninguna,
    this.orden = 0,
    this.horaObjetivo,
  });

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
  }) {
    return Task(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      fecha: fecha,
      completada: completada ?? this.completada,
      prioridad: prioridad ?? this.prioridad,
      orden: orden ?? this.orden,
      horaObjetivo: clearHora ? null : (horaObjetivo ?? this.horaObjetivo),
    );
  }
}
