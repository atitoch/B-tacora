import '../utils/date_utils.dart' as du;

enum Prioridad { ninguna, alta, media, baja }

class Task {
  final int? id;
  final String nombre;
  final DateTime fecha;
  final bool completada;
  final Prioridad prioridad;
  final int orden;

  Task({
    this.id,
    required this.nombre,
    required this.fecha,
    this.completada = false,
    this.prioridad = Prioridad.ninguna,
    this.orden = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'fecha': du.dateKey(fecha),
      'completada': completada ? 1 : 0,
      'prioridad': prioridad.index,
      'orden': orden,
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
    );
  }

  Task copyWith({
    int? id,
    bool? completada,
    String? nombre,
    Prioridad? prioridad,
    int? orden,
  }) {
    return Task(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      fecha: fecha,
      completada: completada ?? this.completada,
      prioridad: prioridad ?? this.prioridad,
      orden: orden ?? this.orden,
    );
  }
}
