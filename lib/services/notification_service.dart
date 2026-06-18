import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/habit.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Cache de la última clave programada por habitId: body + hora + días.
  // Incluir hora/días evita que un cambio de horario no reprograme.
  final Map<int, String> _lastScheduleKey = {};

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    // Establecer la timezone local del dispositivo.
    // Algunos Android devuelven identificadores no estándar (ej. "Etc/Unknown");
    // en ese caso caemos a UTC para evitar crash.
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Limpiar notificaciones previas con formato incompatible (instalaciones
    // anteriores). Si falla, ignorar — los datos corruptos se sobrescriben
    // en el siguiente scheduleHabitNotification.
    try {
      await _plugin.cancelAll();
    } catch (_) {}

    // Android 13+ requiere solicitud explícita en runtime (POST_NOTIFICATIONS).
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> scheduleHabitNotification({
    required Habit habit,
    required int fallosConsecutivos,
  }) async {
    if (habit.id == null) return;

    // Hábito inactivo: cancelar notificaciones pendientes y salir.
    if (!habit.activo) {
      await cancelHabitNotifications(habit.id!);
      return;
    }

    if (habit.horaObjetivo == null) {
      // Sin hora objetivo no hay notificación que programar;
      // cancelar cualquier notificación previa que pudiera haber quedado.
      await cancelHabitNotifications(habit.id!);
      return;
    }

    final body = fallosConsecutivos >= 3
        ? _copyConfronta(habit.nombre, fallosConsecutivos)
        : _copyNeutro(habit.nombre);

    // Dirty-check: incluir hora y días para detectar cambios de horario.
    final hora = habit.horaObjetivo!;
    final dias = habit.tipoFrecuencia == FrecuenciaTipo.diario
        ? 'daily'
        : (habit.diasSemana ?? []).join(',');
    final scheduleKey = '${hora.hour}:${hora.minute}@$dias|$body';
    if (_lastScheduleKey[habit.id] == scheduleKey) return;
    _lastScheduleKey[habit.id!] = scheduleKey;

    await cancelHabitNotifications(habit.id!);

    final diasObjetivo = habit.tipoFrecuencia == FrecuenciaTipo.diario
        ? List.generate(7, (i) => i + 1)
        : (habit.diasSemana ?? []);

    // Programar todos los días en paralelo.
    await Future.wait([
      for (final dia in diasObjetivo)
        _scheduleWeekly(
          id: _notifId(habit.id!, dia),
          title: 'B-tácora',
          body: body,
          diaSemana: dia,
          hora: habit.horaObjetivo!,
        ),
    ]);
  }

  Future<void> cancelHabitNotifications(int habitId) async {
    _lastScheduleKey.remove(habitId);
    try {
      await Future.wait([
        for (int dia = 1; dia <= 7; dia++) _plugin.cancel(_notifId(habitId, dia)),
      ]);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    _lastScheduleKey.clear();
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  Future<void> _scheduleWeekly({
    required int id,
    required String title,
    required String body,
    required int diaSemana,
    required TimeOfDay hora,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    final scheduled = _nextWeekday(now, diaSemana, hora);

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
    // Avanzar al día de la semana correcto; máx 7 iteraciones.
    for (int i = 0; i < 8; i++) {
      if (candidate.weekday == targetWeekday &&
          !candidate.isBefore(from.add(const Duration(seconds: 5)))) {
        return candidate;
      }
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
