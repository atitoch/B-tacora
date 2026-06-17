import '../utils/date_utils.dart' as du;

class DailyNote {
  final int? id;
  final DateTime fecha;
  final String texto;
  final int? nivelEnergia; // 1–5

  DailyNote({
    this.id,
    required this.fecha,
    required this.texto,
    this.nivelEnergia,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'fecha': du.dateKey(fecha),
      'texto': texto,
      'nivel_energia': nivelEnergia,
    };
  }

  factory DailyNote.fromMap(Map<String, dynamic> m) {
    return DailyNote(
      id: m['id'] as int?,
      fecha: DateTime.parse(m['fecha'] as String),
      texto: m['texto'] as String,
      nivelEnergia: m['nivel_energia'] as int?,
    );
  }
}
