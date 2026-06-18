import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/app_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  runApp(const BtacoraApp());
}

class BtacoraApp extends StatelessWidget {
  const BtacoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: 'B-tácora',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        locale: const Locale('es'),
        home: const _AppRoot(),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final seed = const Color(0xFF4A6FA5);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> with WidgetsBindingObserver {
  bool _loading = true;
  bool _firstRun = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Refresca la fecha cuando la app vuelve a foreground tras estar en background.
  /// Corrige el caso en que la app queda abierta de un día para el otro.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AppProvider>().refreshDate();
    }
  }

  Future<void> _init() async {
    final provider = context.read<AppProvider>();
    try {
      await provider.initialize();
    } catch (_) {
      // Notifications or DB error on startup — still proceed to the right screen.
    }
    bool firstRun = false;
    try {
      firstRun = await provider.isFirstRun();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _firstRun = firstRun;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _firstRun ? const OnboardingScreen() : const HomeScreen();
  }
}
