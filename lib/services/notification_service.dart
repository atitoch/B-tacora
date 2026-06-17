import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/habit.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  Future<void> scheduleHabitNotification({
    required Habit habit,
    required int fallosConsecutivos,
  }) async {
    if (habit.id == null || habit.horaObjetivo == null) return;

    await cancelHabitNotifications(habit.id!);

    final title = 'B-tácora';
    final body = fallosConsecutivos >= 3
        ? _copyConfronta(habit.nombre, fallosConsecutivos)
        : _copyNeutro(habit.nombre);

    final diasObjetivo = habit.tipoFrecuencia == FrecuenciaTipo.diario
        ? List.generate(7, (i) => i + 1) // todos
        : (habit.diasSemana ?? []);

    for (final dia in diasObjetivo) {
      final notifId = _notifId(habit.id!, dia);
      await _scheduleWeekly(
        id: notifId,
        title: title,
        body: body,
        diaSemana: dia,
        hora: habit.horaObjetivo!,
      );
    }
  }

  Future<void> cancelHabitNotifications(int habitId) async {
    for (int dia = 1; dia <= 7; dia++) {
      await _plugin.cancel(_notifId(habitId, dia));
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  Future<void> _scheduleWeekly({
    required int id,
    required String title,
    required String body,
    required int diaSemana, // 1=Lun, 7=Dom (dart weekday)
    required TimeOfDay hora,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = _nextWeekday(now, diaSemana, hora);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'btacora_habitos',
          'Hábitos',
          channelDescription: 'Recordatorios de hábitos diarios',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  tz.TZDateTime _nextWeekday(
      tz.TZDateTime from, int targetWeekday, TimeOfDay hora) {
    var candidate = tz.TZDateTime(
      tz.local,
      from.year,
      from.month,
      from.day,
      hora.hour,
      hora.minute,
    );
    // Avanzar hasta el día de la semana correcto
    while (candidate.weekday != targetWeekday ||
        candidate.isBefore(from.add(const Duration(seconds: 5)))) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  String _copyNeutro(String nombre) => '$nombre — hora de cumplirlo.';

  String _copyConfronta(String nombre, int dias) {
    final mensajes = [
      'Llevas $dias días sin "$nombre". ¿Qué cambió?',
      '$dias días sin "$nombre". ¿Es un bloqueo real o es evitación?',
      'El patrón habla: $dias días sin "$nombre". ¿Qué necesitas para retomarlo?',
    ];
    return mensajes[dias % mensajes.length];
  }

  int _notifId(int habitId, int diaSemana) => habitId * 10 + diaSemana;
}
