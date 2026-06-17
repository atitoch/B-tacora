import '../utils/date_utils.dart' as du;

class Task {
  final int? id;
  final String nombre;
  final DateTime fecha;
  final bool completada;

  Task({
    this.id,
    required this.nombre,
    required this.fecha,
    this.completada = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'fecha': du.dateKey(fecha),
      'completada': completada ? 1 : 0,
    };
  }

  factory Task.fromMap(Map<String, dynamic> m) {
    return Task(
      id: m['id'] as int?,
      nombre: m['nombre'] as String,
      fecha: DateTime.parse(m['fecha'] as String),
      completada: (m['completada'] as int) == 1,
    );
  }

  Task copyWith({int? id, bool? completada, String? nombre}) {
    return Task(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      fecha: fecha,
      completada: completada ?? this.completada,
    );
  }
}
