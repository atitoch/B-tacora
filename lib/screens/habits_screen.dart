import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/habit_tile.dart';

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final habitos = provider.habitsDeLaFecha;

    if (habitos.isEmpty) {
      return const Center(
        child: Text(
          'Sin hábitos para hoy.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      buildDefaultDragHandles: false,
      onReorderItem: context.read<AppProvider>().reorderHabits,
      itemCount: habitos.length,
      itemBuilder: (ctx, i) => HabitTile(
        key: ValueKey(habitos[i].id),
        habit: habitos[i],
        index: i,
      ),
    );
  }
}
