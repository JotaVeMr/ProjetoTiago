// lib/main.dart
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
import 'pages/configurar_perfil_page.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Inicialização
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
  await NotificationService().init();

  runApp(const MyApp());

  FlutterNativeSplash.remove();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;

  /// null = tema do sistema
  /// true = dark
  /// false = light
  bool? _manualTheme;

  Future<Map<String, dynamic>> _loadInit() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'onboardingDone': prefs.getBool('onboarding_completed') ?? false,
      'hasUser': prefs.containsKey('usuarioSelecionado'),
      'theme': prefs.getBool('isDarkTheme'), // null = seguir sistema
    };
  }

  /// Atualiza tema em tempo real
  void _onThemeChanged(bool? themeValue) async {
    final prefs = await SharedPreferences.getInstance();

    if (themeValue == null) {
      await prefs.remove('isDarkTheme');
    } else {
      await prefs.setBool('isDarkTheme', themeValue);
    }

    setState(() => _manualTheme = themeValue);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadInit(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final onboardingDone = snapshot.data!['onboardingDone'] as bool;
        final hasUser = snapshot.data!['hasUser'] as bool;
        final savedTheme = snapshot.data!['theme'] as bool?;

        // 🔹 o tema é sempre recarregado aqui
        _manualTheme = savedTheme;

        final List<Widget> pages = [
          const HomePage(),
          TratamentosPage(),
          const RelatorioPage(),
          ConfiguracoesPage(
            isDarkTheme: _manualTheme,
            onThemeChanged: _onThemeChanged,
          ),
        ];

        return MaterialApp(
          debugShowCheckedModeBanner: false,

          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('pt', 'BR')],
          locale: const Locale('pt', 'BR'),

          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),

          themeMode: _manualTheme == null
              ? ThemeMode.system
              : (_manualTheme! ? ThemeMode.dark : ThemeMode.light),

          home: onboardingDone == false
              ? const OnboardingPage()
              : hasUser == false
                  ? const ConfigurarPerfilPage()
                  : Scaffold(
                      body: pages[_selectedIndex],
                      bottomNavigationBar: BottomNavigationBar(
                        currentIndex: _selectedIndex,
                        selectedItemColor: Colors.blue,
                        unselectedItemColor: Colors.grey,
                        onTap: (index) => setState(() => _selectedIndex = index),
                        items: const [
                          BottomNavigationBarItem(
                              icon: Icon(Icons.home), label: "Início"),
                          BottomNavigationBarItem(
                              icon: Icon(Icons.medication),
                              label: "Medicamentos"),
                          BottomNavigationBarItem(
                              icon: Icon(Icons.bar_chart_outlined),
                              label: "Relatórios"),
                          BottomNavigationBarItem(
                              icon: Icon(Icons.settings),
                              label: "Configurações"),
                        ],
                      ),
                    ),
        );
      },
    );
  }
}
