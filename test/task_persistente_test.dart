import 'package:flutter_test/flutter_test.dart';
import 'package:btacora/models/task.dart';

void main() {
  final creada = DateTime(2026, 9, 26);

  test('pendiente persistente: sin completar en ningún día', () {
    final t = Task(nombre: 'x', fecha: creada, persistente: true);
    expect(t.completadaEn(DateTime(2026, 9, 29)), isFalse);
    expect(t.diasArrastrada(DateTime(2026, 9, 29)), 3);
    expect(t.diasArrastrada(creada), 0);
  });

  test('completada después seguía pendiente en días anteriores', () {
    final t = Task(
      nombre: 'x',
      fecha: creada,
      persistente: true,
      completada: true,
      fechaCompletada: DateTime(2026, 9, 28),
    );
    expect(t.completadaEn(DateTime(2026, 9, 27)), isFalse);
    expect(t.completadaEn(DateTime(2026, 9, 28)), isTrue);
  });

  test('toMap/fromMap conserva persistencia y fecha de completado', () {
    final t = Task(
      id: 1,
      nombre: 'x',
      fecha: creada,
      persistente: true,
      completada: true,
      fechaCompletada: DateTime(2026, 9, 28),
    );
    final r = Task.fromMap(t.toMap());
    expect(r.persistente, isTrue);
    expect(r.fechaCompletada, DateTime(2026, 9, 28));
  });
}
