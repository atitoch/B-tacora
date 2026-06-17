import 'package:flutter/material.dart';
import '../utils/date_utils.dart' as du;

enum FrecuenciaTipo { diario, diasEspecificos }

class Habit {
  final int? id;
  final String nombre;
  final FrecuenciaTipo tipoFrecuencia;
  final List<int>? diasSemana; // 1=Lun … 7=Dom
  final TimeOfDay? horaObjetivo;
  final bool activo;
  final DateTime? fechaCreacion;

  Habit({
    this.id,
    required this.nombre,
    required this.tipoFrecuencia,
    this.diasSemana,
    this.horaObjetivo,
    this.activo = true,
    this.fechaCreacion,
  });

  bool tocaHoy(DateTime fecha) {
    if (!activo) return false;
    if (tipoFrecuencia == FrecuenciaTipo.diario) return true;
    final diaSemana = fecha.weekday; // 1=Lun, 7=Dom
    return diasSemana?.contains(diaSemana) ?? false;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'tipo_frecuencia': tipoFrecuencia.index,
      'dias_semana': diasSemana?.join(','),
      'hora_h': horaObjetivo?.hour,
      'hora_m': horaObjetivo?.minute,
      'activo': activo ? 1 : 0,
      'fecha_creacion': fechaCreacion != null ? du.dateKey(fechaCreacion!) : null,
    };
  }

  factory Habit.fromMap(Map<String, dynamic> m) {
    return Habit(
      id: m['id'] as int?,
      nombre: m['nombre'] as String,
      tipoFrecuencia: FrecuenciaTipo.values[m['tipo_frecuencia'] as int],
      diasSemana: () {
        final raw = m['dias_semana'] as String?;
        if (raw == null || raw.isEmpty) return null;
        return raw.split(',').map(int.parse).toList();
      }(),
      horaObjetivo: (m['hora_h'] != null && m['hora_m'] != null)
          ? TimeOfDay(hour: m['hora_h'] as int, minute: m['hora_m'] as int)
          : null,
      activo: (m['activo'] as int) == 1,
      fechaCreacion: (m['fecha_creacion'] as String?) != null
          ? DateTime.parse(m['fecha_creacion'] as String)
          : null,
    );
  }

  Habit copyWith({
    int? id,
    String? nombre,
    FrecuenciaTipo? tipoFrecuencia,
    List<int>? diasSemana,
    TimeOfDay? horaObjetivo,
    bool? activo,
    DateTime? fechaCreacion,
  }) {
    return Habit(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      tipoFrecuencia: tipoFrecuencia ?? this.tipoFrecuencia,
      diasSemana: diasSemana ?? this.diasSemana,
      horaObjetivo: horaObjetivo ?? this.horaObjetivo,
      activo: activo ?? this.activo,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }
}
