import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/habit.dart';
import '../models/task.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Anticipación en minutos: la notificación se dispara este número de minutos
  // ANTES de la hora objetivo del hábito/tarea. Configurable por el usuario.
  int anticipacionMinutos = 0;

  // Base de IDs para notificaciones de tareas. Mantiene un espacio separado del
  // de hábitos (habitId*10 + díaSemana) para evitar colisiones.
  static const int _taskIdBase = 1000000000;

  // Cache de la última clave programada por habitId: body + hora + días + offset.
  // Incluir hora/días/offset evita que un cambio no reprograme.
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
    // en el siguiente schedule.
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

  // ─── Hábitos ───────────────────────────────────────────────────────────────

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

    // Dirty-check: incluir hora, días y offset para detectar cualquier cambio.
    final hora = habit.horaObjetivo!;
    final dias = habit.tipoFrecuencia == FrecuenciaTipo.diario
        ? 'daily'
        : (habit.diasSemana ?? []).join(',');
    final scheduleKey =
        '${hora.hour}:${hora.minute}@$dias~$anticipacionMinutos|$body';
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

  /// Instante de la próxima notificación para un (día de la semana, hora),
  /// restando la anticipación configurada. El instante resultante puede caer en
  /// un día/hora distinto al objetivo (ej. 00:10 con 15 min de anticipación cae
  /// el día anterior a las 23:55); matchDateTimeComponents usa ese instante para
  /// la recurrencia semanal, por lo que la anticipación se mantiene cada semana.
  tz.TZDateTime _nextWeekday(
      tz.TZDateTime from, int targetWeekday, TimeOfDay hora) {
    // Evento (hora objetivo) en el próximo día de la semana correcto.
    var evento = tz.TZDateTime(
      tz.local,
      from.year,
      from.month,
      from.day,
      hora.hour,
      hora.minute,
    );
    for (int i = 0; i < 8; i++) {
      if (evento.weekday == targetWeekday) break;
      evento = evento.add(const Duration(days: 1));
    }
    var scheduled = evento.subtract(Duration(minutes: anticipacionMinutos));
    // Si ya pasó (incluye margen), saltar a la próxima semana.
    if (scheduled.isBefore(from.add(const Duration(seconds: 5)))) {
      scheduled = scheduled.add(const Duration(days: 7));
    }
    return scheduled;
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

  // ─── Tareas ──────────────────────────────────────────────────────────────

  /// Programa el recordatorio de una tarea con hora objetivo: único para tareas
  /// normales, diario para las persistentes. Si la tarea no tiene hora, está
  /// completada o (siendo normal) el instante ya pasó, cancela.
  Future<void> scheduleTaskNotification(Task task) async {
    if (task.id == null) return;

    if (task.horaObjetivo == null || task.completada) {
      await cancelTaskNotification(task.id!);
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      task.fecha.year,
      task.fecha.month,
      task.fecha.day,
      task.horaObjetivo!.hour,
      task.horaObjetivo!.minute,
    ).subtract(Duration(minutes: anticipacionMinutos));

    final limite = now.add(const Duration(seconds: 5));
    if (task.persistente) {
      // Persistente: se recuerda cada día a la misma hora hasta completarse.
      // Avanzar al primer instante futuro a partir de su fecha original.
      while (scheduled.isBefore(limite)) {
        scheduled = tz.TZDateTime(tz.local, scheduled.year, scheduled.month,
            scheduled.day + 1, scheduled.hour, scheduled.minute);
      }
    } else if (scheduled.isBefore(limite)) {
      // Notificación de una sola vez: si ya pasó, no programar.
      await cancelTaskNotification(task.id!);
      return;
    }

    await _plugin.zonedSchedule(
      _taskNotifId(task.id!),
      'B-tácora · Tarea',
      task.nombre,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'btacora_tareas',
          'Tareas',
          channelDescription: 'Recordatorios de tareas con hora',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // Persistente → se repite diario (se cancela al completarla);
      // si no, sin matchDateTimeComponents → notificación única.
      matchDateTimeComponents:
          task.persistente ? DateTimeComponents.time : null,
    );
  }

  Future<void> cancelTaskNotification(int taskId) async {
    try {
      await _plugin.cancel(_taskNotifId(taskId));
    } catch (_) {}
  }

  int _taskNotifId(int taskId) => _taskIdBase + taskId;
}
