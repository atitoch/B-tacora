import 'package:flutter/material.dart';
import '../models/habit.dart';

class HabitFormDialog extends StatefulWidget {
  final Habit? habit; // null = crear, non-null = editar

  const HabitFormDialog({super.key, this.habit});

  @override
  State<HabitFormDialog> createState() => _HabitFormDialogState();
}

class _HabitFormDialogState extends State<HabitFormDialog> {
  final _nombreCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  FrecuenciaTipo _tipo = FrecuenciaTipo.diario;
  final Set<int> _dias = {};
  TimeOfDay? _hora;

  static const _diasLabel = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  void initState() {
    super.initState();
    final h = widget.habit;
    if (h != null) {
      _nombreCtrl.text = h.nombre;
      _tipo = h.tipoFrecuencia;
      if (h.diasSemana != null) _dias.addAll(h.diasSemana!);
      _hora = h.horaObjetivo;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _hora ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _hora = picked);
  }

  void _clearTime() => setState(() => _hora = null);

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_tipo == FrecuenciaTipo.diasEspecificos && _dias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un día')),
      );
      return;
    }

    final result = Habit(
      id: widget.habit?.id,
      nombre: _nombreCtrl.text.trim(),
      tipoFrecuencia: _tipo,
      diasSemana: _tipo == FrecuenciaTipo.diasEspecificos
          ? (_dias.toList()..sort())
          : null,
      horaObjetivo: _hora,
      activo: widget.habit?.activo ?? true,
      fechaCreacion: widget.habit?.fechaCreacion,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esEdicion = widget.habit != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              esEdicion ? 'Editar hábito' : 'Nuevo hábito',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),

            // Nombre
            TextFormField(
              controller: _nombreCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre del hábito',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
            ),
            const SizedBox(height: 20),

            // Frecuencia
            Text('Frecuencia', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            SegmentedButton<FrecuenciaTipo>(
              segments: const [
                ButtonSegment(
                  value: FrecuenciaTipo.diario,
                  label: Text('Diario'),
                  icon: Icon(Icons.repeat),
                ),
                ButtonSegment(
                  value: FrecuenciaTipo.diasEspecificos,
                  label: Text('Días específicos'),
                  icon: Icon(Icons.date_range),
                ),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) =>
                  setState(() => _tipo = s.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),

            // Selector de días (solo cuando diasEspecificos)
            if (_tipo == FrecuenciaTipo.diasEspecificos) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                children: List.generate(7, (i) {
                  final dia = i + 1; // 1=Lun … 7=Dom
                  final sel = _dias.contains(dia);
                  return FilterChip(
                    label: Text(_diasLabel[i]),
                    selected: sel,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _dias.add(dia);
                      } else {
                        _dias.remove(dia);
                      }
                    }),
                  );
                }),
              ),
            ],

            const SizedBox(height: 20),

            // Hora objetivo (opcional)
            Text('Hora objetivo (opcional)', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.access_time, size: 18),
                  label: Text(
                    _hora != null ? _hora!.format(context) : 'Sin hora',
                  ),
                  onPressed: _pickTime,
                ),
                if (_hora != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Quitar hora',
                    onPressed: _clearTime,
                  ),
                ],
              ],
            ),
            if (_hora != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Te recordaremos a esta hora (ajustable en Notificaciones).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(esEdicion ? 'Guardar cambios' : 'Crear hábito'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
