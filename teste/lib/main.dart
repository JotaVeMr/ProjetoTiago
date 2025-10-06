// lib/main.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'pages/home_page.dart';
import 'pages/tratamentos_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/configuracoes_page.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Inicializa timezone e notificações
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
  await NotificationService().init();

  // 🔹 Verifica se é a primeira inicialização
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_completed') ?? false;

  // 🔹 Carrega o tema salvo (true = escuro, false = claro)
  final isDarkTheme = prefs.getBool('isDarkTheme') ?? false;

  runApp(MyApp(
    onboardingDone: onboardingDone,
    isDarkTheme: isDarkTheme,
  ));

  FlutterNativeSplash.remove();
}

class MyApp extends StatefulWidget {
  final bool onboardingDone;
  final bool isDarkTheme;

  const MyApp({
    super.key,
    required this.onboardingDone,
    required this.isDarkTheme,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;
  late bool _isDarkTheme;

  @override
  void initState() {
    super.initState();
    _isDarkTheme = widget.isDarkTheme;
  }

  void _onThemeChanged(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkTheme', value);
    setState(() => _isDarkTheme = value);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Agora criamos as páginas *aqui*, com o tema já definido
    final List<Widget> pages = [
      const HomePage(),
      TratamentosPage(),
      ConfiguracoesPage(
        isDarkTheme: _isDarkTheme,
        onThemeChanged: _onThemeChanged,
      ),
    ];

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // 🌎 Localização configurada
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      locale: const Locale('pt', 'BR'),

      // 🎨 Suporte a tema claro/escuro
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _isDarkTheme ? ThemeMode.dark : ThemeMode.light,

      // 👇 Verifica se deve abrir Onboarding ou App normal
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
                      icon: Icon(Icons.settings), label: "Configurações"),
                ],
              ),
            )
          : const OnboardingPage(),
    );
  }
}
