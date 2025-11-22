// lib/main.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'pages/relatorio_page.dart';
import 'pages/home_page.dart';
import 'pages/tratamentos_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/configuracoes_page.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
  await NotificationService().init();

  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_completed') ?? false;

  // se não existir, significa "seguir o tema do sistema"
  final isDarkTheme = prefs.getBool('isDarkTheme');

  runApp(MyApp(
    onboardingDone: onboardingDone,
    savedTheme: isDarkTheme, // null = seguir sistema
  ));

  FlutterNativeSplash.remove();
}

class MyApp extends StatefulWidget {
  final bool onboardingDone;
  final bool? savedTheme; // null = sistema

  const MyApp({
    super.key,
    required this.onboardingDone,
    required this.savedTheme,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;

  /// null  = seguir sistema  
  /// true  = forçar tema escuro  
  /// false = forçar tema claro
  bool? _manualTheme;

  @override
  void initState() {
    super.initState();
    _manualTheme = widget.savedTheme;
  }

  /// Atualiza tema (null = sistema)
  void _onThemeChanged(bool? themeValue) async {
    final prefs = await SharedPreferences.getInstance();

    if (themeValue == null) {
      await prefs.remove('isDarkTheme'); // remove = segue sistema
    } else {
      await prefs.setBool('isDarkTheme', themeValue);
    }

    setState(() => _manualTheme = themeValue);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const HomePage(),
      TratamentosPage(),
      const RelatorioPage(),
      ConfiguracoesPage(
        isDarkTheme: _manualTheme,   // ← agora aceita null
        onThemeChanged: _onThemeChanged,
      ),
    ];

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ======= LOCALIZAÇÃO =======
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      locale: const Locale('pt', 'BR'),

      // ======= TEMAS =======
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),

      // regra principal do tema:
      themeMode: _manualTheme == null
          ? ThemeMode.system
          : (_manualTheme! ? ThemeMode.dark : ThemeMode.light),

      // ======= HOME =======
      home: widget.onboardingDone
          ? Scaffold(
              body: pages[_selectedIndex],
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: _selectedIndex,
                selectedItemColor: Colors.blue,
                unselectedItemColor: Colors.grey,
                onTap: (index) {
                  setState(() => _selectedIndex = index);
                },
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.home), label: "Início"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.medication), label: "Medicamentos"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.bar_chart_outlined), label: "Relatórios"),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.settings), label: "Configurações"),
                ],
              ),
            )
          : const OnboardingPage(),
    );
  }
}
