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

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: habitos.length,
      itemBuilder: (ctx, i) => HabitTile(habit: habitos[i]),
    );
  }
}
