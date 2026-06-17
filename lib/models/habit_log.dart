class HabitLog {
  final int? id;
  final int habitId;
  final DateTime fecha;
  final bool completado;
  final String? nota;

  HabitLog({
    this.id,
    required this.habitId,
    required this.fecha,
    required this.completado,
    this.nota,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'habit_id': habitId,
      'fecha': _dateKey(fecha),
      'completado': completado ? 1 : 0,
      'nota': nota,
    };
  }

  factory HabitLog.fromMap(Map<String, dynamic> m) {
    return HabitLog(
      id: m['id'] as int?,
      habitId: m['habit_id'] as int,
      fecha: DateTime.parse(m['fecha'] as String),
      completado: (m['completado'] as int) == 1,
      nota: m['nota'] as String?,
    );
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
