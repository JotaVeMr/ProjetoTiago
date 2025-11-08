// lib/pages/home_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/medicamento.dart';
import '../models/usuario.dart';
import '../services/notification_service.dart';
import '../services/database_helper.dart';
import '../services/app_event_bus.dart';
import 'add_medicamento_page.dart';
import 'configurar_perfil_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Usuario? usuarioSelecionado;
  List<Medicamento> medicamentos = [];
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _requestNotificationPermission();
     _init();
    
    

    // Ouve alterações globais (ex.: exclusão/edição/adição na aba Medicamentos ou perfis)
    AppEventBus.I.medicamentosChanged.addListener(_loadMedicamentos);
    _loadUsuarioSelecionado();
  }

      Future<void> _init() async {
      await DatabaseHelper.instance.marcarPendentesComoNaoTomados();
      await _loadMedicamentos();
    }
  Future<void> _requestNotificationPermission() async {
  final plugin = FlutterLocalNotificationsPlugin();

  // Android
 final android =
    plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await android?.requestNotificationsPermission();

  // iOS
  final ios =
      plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
  await ios?.requestPermissions(
    alert: true,
    badge: true,
    sound: true,
  );
}

  @override
  void dispose() {
    AppEventBus.I.medicamentosChanged.removeListener(_loadMedicamentos);
    super.dispose();
  }

  /// Carrega usuário selecionado do SharedPreferences
  Future<void> _loadUsuarioSelecionado() async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioJson = prefs.getString("usuarioSelecionado");

    if (usuarioJson != null) {
      setState(() {
        // usamos toMap() na hora de salvar => aqui usamos fromMap
        usuarioSelecionado = Usuario.fromMap(jsonDecode(usuarioJson));
      });
      await _loadMedicamentos();
    } else {
      // sem usuário selecionado, não forçamos navegação. Mostra "Perfil" no topo.
      setState(() {
        usuarioSelecionado = null;
        medicamentos = [];
      });
    }
  }
//   void _testarNotificacaoAgora() async {
//   final agora = DateTime.now().add(const Duration(seconds: 10));
//   await NotificationService().scheduleNotification(
//     999, // id fictício
//     "Teste imediato",
//     "Notificação de teste enviada com sucesso!",
//     agora,
//   );
//     print("🧩 Notificação de teste agendada para ${agora.toIso8601String()}");
// }

  /// Carrega medicamentos do DB e SharedPreferences (por usuário)
  Future<void> _loadMedicamentos() async {
    if (!mounted) return;

    if (usuarioSelecionado == null || usuarioSelecionado!.id == null) {
      setState(() => medicamentos = []);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('medicamentos_${usuarioSelecionado!.id}') ?? [];
    List<Medicamento> prefsList =
    data.map((e) => Medicamento.fromJson(jsonDecode(e))).toList();

    final agora = DateTime.now();
      for (var med in prefsList) {
        if (med.dataHoraAgendamento != null) {
          final dataAgendada = DateTime.parse(med.dataHoraAgendamento!);
          if (dataAgendada.isBefore(agora) &&
              med.isTaken == false &&
              med.isIgnored == false) {
            med.isPendente = true;
            await DatabaseHelper.instance.updateMedicamento(med);
          }
        }
      }

// ✅ Marca automaticamente como NÃO TOMADOS no banco (para o gráfico)
        //await DatabaseHelper.instance.marcarPendentesComoNaoTomados();

    // busca do SQLite filtrando por usuarioId
    List<Medicamento> dbList = await DatabaseHelper.instance
        .getMedicamentos(usuarioId: usuarioSelecionado!.id!);

    // unifica (prefere o último por chave)
    final Map<String, Medicamento> mapa = {};
    for (final m in prefsList) {
      final key =
          m.id != null ? 'id_${m.id}' : 'pref_${m.nome}_${m.dataHoraAgendamento}';
      mapa[key] = m;
    }
    for (final m in dbList) {
      final key =
          m.id != null ? 'id_${m.id}' : 'db_${m.nome}_${m.dataHoraAgendamento}';
      mapa[key] = m;
    }

    // Atualiza automaticamente status PENDENTE
    final now = DateTime.now();
    for (var med in mapa.values) {
      if (!med.isTaken && !med.isIgnored && med.scheduledDateTime.isBefore(now)) {
        med.isPendente = true;
        await DatabaseHelper.instance.updateMedicamento(med);
      }
    }
  await DatabaseHelper.instance.marcarPendentesComoNaoTomados();


    setState(() {
      medicamentos = mapa.values.toList();
      medicamentos.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));
    });

    await _syncToStorage();
  }

  Future<void> _saveMedicamentosLocalOnly() async {
    if (usuarioSelecionado == null || usuarioSelecionado!.id == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'medicamentos_${usuarioSelecionado!.id}',
      medicamentos.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> _syncToStorage() async {
    if (usuarioSelecionado == null || usuarioSelecionado!.id == null) return;
    final prefs = await SharedPreferences.getInstance();

    for (final med in medicamentos) {
      med.usuarioId = usuarioSelecionado!.id; // garante vínculo
      if (med.id != null) {
        await DatabaseHelper.instance.updateMedicamento(med);
      } else {
        final newId = await DatabaseHelper.instance.insertMedicamento(med);
        if (newId != 0) med.id = newId;
      }
    }

    await prefs.setStringList(
      'medicamentos_${usuarioSelecionado!.id}',
      medicamentos.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  /// Lista de medicamentos que aparecem NA LISTA (considera o período)
  List<Medicamento> _getMedicamentosForSelectedDay(DateTime day) {
    return medicamentos.where((med) {
      final inicio = DateTime.parse(med.dataInicio);
      final fim = DateTime.parse(med.dataFim);
      final diaSelecionado = DateTime(day.year, day.month, day.day);

      return (diaSelecionado.isAfter(inicio.subtract(const Duration(days: 1))) &&
          diaSelecionado.isBefore(fim.add(const Duration(days: 1))));
    }).toList();
  }

  /// Eventos do calendário → bolinha só na data INICIAL
  List<dynamic> _getEventosDoCalendario(DateTime day) {
    return medicamentos.where((med) {
      final inicio = DateTime.parse(med.dataInicio);
      return isSameDay(day, inicio);
    }).toList();
  }

  void _navigateToAddMedicamentoPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddMedicamentoPage()),
    );
    if (result == true) {
      await _loadMedicamentos();
    }
  }

  void _navigateToConfigurarPerfilPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ConfigurarPerfilPage()),
    );
    if (result == true) {
      await _loadUsuarioSelecionado(); // recarrega seleção e medicamentos
    }
  }

  /// Seletor rápido de perfis (BottomSheet)
  Future<void> _openSeletorPerfil() async {
    final usuarios = await DatabaseHelper.instance.getUsuarios();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Trocar perfil',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              if (usuarios.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Nenhum perfil cadastrado.'),
                ),

              ...usuarios.map((u) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        u.nome.isNotEmpty ? u.nome.characters.first.toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(u.nome),
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('usuarioSelecionado', jsonEncode(u.toMap()));
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      setState(() => usuarioSelecionado = u);
                      await _loadMedicamentos();
                    },
                  )),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.manage_accounts),
                title: const Text('Gerenciar perfis'),
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateToConfigurarPerfilPage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ==== UTILITÁRIOS DE TEXTO / COMPARTILHAMENTO ====

  /// Monta um texto com 1 ou mais medicamentos.
  String _montarResumoMedicamentos({
    required Usuario perfil,
    required List<Medicamento> meds,
    DateTime? dia,
    DateTime? inicio,
    DateTime? fim,
  }) {
    final dfData = DateFormat('dd/MM/yyyy');
    final dfHora = DateFormat('HH:mm');

    final cab = StringBuffer()
      ..writeln('📋 Agenda de medicamentos PharmSync')
      ..writeln('👤 Paciente: ${perfil.nome}');
    if (inicio != null && fim != null) {
      cab.writeln('🗓 Período: ${dfData.format(inicio)} a ${dfData.format(fim)}');
    } else if (dia != null) {
      cab.writeln('🗓 Dia: ${dfData.format(dia)}');
    }
    cab.writeln('');

    final corpo = StringBuffer();
    if (meds.isEmpty) {
      corpo.writeln('Sem medicamentos neste período.');
    } else {
      for (final m in meds) {
        final nome = m.nome;
        final tipo = m.tipo;
        final dose = m.dose;
        final h =
            m.scheduledDateTime != null ? dfHora.format(m.scheduledDateTime) : '';
        final ini = DateFormat('dd/MM/yyyy').format(DateTime.parse(m.dataInicio));
        final ff = DateFormat('dd/MM/yyyy').format(DateTime.parse(m.dataFim));

        corpo.writeln('• $nome'
            '${tipo.isNotEmpty ? ' ($tipo)' : ''}'
            '${dose.isNotEmpty ? ' - $dose' : ''}'
            '${h.isNotEmpty ? ' - $h' : ''}');
        corpo.writeln('  Tratamento: $ini até $ff');


        if (m.isTaken || m.isIgnored || m.isPendente) {
          final status = m.isTaken
              ? 'Tomado'
              : m.isIgnored
                  ? 'Esquecido'
                  : 'Pendente';
          corpo.writeln('  Status: $status');
        }

        corpo.writeln('');
      }
    }

    return (cab.toString() + corpo.toString()).trimRight();
  }

  // ==== Pop-up de ações do medicamento (sem copiar/compartilhar aqui, somente no menu ⋮) ====
  void _showMedicamentoActions(Medicamento medicamento, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bc) {
        return Container(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  height: 5,
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                  margin: const EdgeInsets.only(bottom: 10),
                ),
                Text(
                  medicamento.nome,
                  style:
                      const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                Text(
                  "Tomar ${medicamento.dose}",
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // TOMAR AGORA
                SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      medicamento.isTaken = true;
                      medicamento.isIgnored = false;
                      medicamento.isPendente = false;
                    });

                    await DatabaseHelper.instance.updateMedicamento(medicamento);

                    // ✅ registra dose no histórico
                   if (medicamento.id != null) {
                    print("🔎 registrando dose para ${medicamento.nome} (id: ${medicamento.id})");

                    try {
                      await DatabaseHelper.instance.registrarDose(
                        medicamentoId: medicamento.id!,
                        status: 'Tomado',
                      );
                      print("✅ dose registrada no banco!");
                    } catch (e) {
                      print("❌ erro ao registrar dose: $e");
                    }
                  }
                    await _saveMedicamentosLocalOnly();
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${medicamento.nome} marcado como tomado!'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Tomar agora", style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 10),

                // REAGENDAR
                SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final DateTime? newDate = await showDatePicker(
                      context: context,
                      initialDate: medicamento.scheduledDateTime,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (newDate == null) return;

                    final TimeOfDay? newTime = await showTimePicker(
                      context: context,
                      initialTime: medicamento.scheduledTimeOfDay,
                    );
                    if (newTime == null) return;

                    final DateTime newScheduledDateTime = DateTime(
                      newDate.year,
                      newDate.month,
                      newDate.day,
                      newTime.hour,
                      newTime.minute,
                    );

                    setState(() {
                      medicamento.dataHoraAgendamento =
                          newScheduledDateTime.toIso8601String();
                      medicamento.isTaken = false;
                      medicamento.isIgnored = false;
                      medicamento.isPendente = false;
                    });

                    await DatabaseHelper.instance.updateMedicamento(medicamento);
                    await _saveMedicamentosLocalOnly();

                    NotificationService().scheduleNotification(
                      medicamento.id ??
                          newScheduledDateTime.millisecondsSinceEpoch % 100000,
                      "Hora do medicamento",
                      "É hora de tomar ${medicamento.nome} - ${medicamento.dose}",
                      newScheduledDateTime,
                    );

                    await _loadMedicamentos();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${medicamento.nome} reagendado para ${TimeOfDay(hour: newScheduledDateTime.hour, minute: newScheduledDateTime.minute).format(context)}',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Reagendar", style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 10),

                // ESQUECIDO
                SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    setState(() {
                      medicamento.isTaken = false;
                      medicamento.isIgnored = true;
                      medicamento.isPendente = false;
                    });

                    await DatabaseHelper.instance.updateMedicamento(medicamento);

                    // ✅ registra dose no histórico
                    if (medicamento.id != null) {
                      await DatabaseHelper.instance.registrarDose(
                        medicamentoId: medicamento.id!,
                        status: 'Esquecido',
                      );
                    }

                    await _saveMedicamentosLocalOnly();
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${medicamento.nome} marcado como esquecido.'),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: const BorderSide(color: Colors.orange),
                  ),
                  child: const Text("Esquecido", style: TextStyle(fontSize: 18)),
                ),
              ),
                const SizedBox(height: 10),

                // CANCELAR
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: Colors.red),
                    ),
                    child:
                        const Text("Cancelar", style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final medicamentosForSelectedDay =
        _selectedDay != null ? _getMedicamentosForSelectedDay(_selectedDay!) : [];
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leadingWidth: 140,
        leading: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _openSeletorPerfil, // seletor rápido de perfil
          child: Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    (usuarioSelecionado?.nome.isNotEmpty ?? false)
                        ? usuarioSelecionado!.nome.characters.first.toUpperCase()
                        : 'P',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          usuarioSelecionado?.nome ?? 'Perfil',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        title: RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            children: <TextSpan>[
              TextSpan(text: 'pharm', style: TextStyle(color: Colors.blue)),
              TextSpan(text: 'Sync', style: TextStyle(color: Colors.black)),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black54),
            onPressed: _navigateToConfigurarPerfilPage, // gerenciar perfis
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            locale: 'pt_BR',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            availableCalendarFormats: const {CalendarFormat.week: 'Semana'},
            availableGestures: AvailableGestures.all,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              if (_calendarFormat != CalendarFormat.week) {
                setState(() {
                  _calendarFormat = CalendarFormat.week;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.lightBlueAccent,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
            eventLoader: (day) {
              // bolinha só no INÍCIO de cada tratamento
              return _getEventosDoCalendario(day);
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isNotEmpty) {
                  return Positioned(
                    bottom: 1,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration:  BoxDecoration(
                        color: isDark ? Colors.white : Colors.black,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: medicamentosForSelectedDay.isEmpty
                ? const Center(
                    child: Text("Nenhum medicamento agendado para este dia."),
                  )
                : ListView.builder(
                    itemCount: medicamentosForSelectedDay.length,
                    itemBuilder: (context, index) {
                      final med = medicamentosForSelectedDay[index];
                      return Card(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            med.nome,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${med.tipo} - ${med.dose} - ${med.scheduledTimeOfDay.format(context)}",
                                style: const TextStyle(color: Colors.grey),
                              ),
                              Text(
                                "Tratamento: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(med.dataInicio))} até ${DateFormat('dd/MM/yyyy').format(DateTime.parse(med.dataFim))}",
                                style: const TextStyle(
                                    color: Color.fromARGB(136, 58, 67, 112), //mudei a cor da Tratamento(Tema dark estava muito escuro)
                                    fontStyle: FontStyle.italic,
                                    fontSize: 13),
                              ),
                              if (med.isTaken)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    "Tomado",
                                    style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              if (med.isIgnored)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    "Esquecido",
                                    style: TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              if (med.isPendente)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    "Pendente",
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (usuarioSelecionado == null) return;
                              if (v == 'copy_one') {
                                final texto = _montarResumoMedicamentos(
                                  perfil: usuarioSelecionado!,
                                  meds: [med],
                                  dia: med.scheduledDateTime,
                                );
                                await Clipboard.setData(
                                    ClipboardData(text: texto));
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Texto copiado')),
                                );
                              } else if (v == 'share_one') {
                                final texto = _montarResumoMedicamentos(
                                  perfil: usuarioSelecionado!,
                                  meds: [med],
                                  dia: med.scheduledDateTime,
                                );
                                await Share.share(texto);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'copy_one',
                                child: Text('Copiar'),
                              ),
                              PopupMenuItem(
                                value: 'share_one',
                                child: Text('Compartilhar'),
                              ),
                            ],
                          ),
                          onTap: () => _showMedicamentoActions(med, index),
                        ),
                      );
                    },
                  ),
          ),
          
        ],
      ),
      
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddMedicamentoPage,
        label: const Text("Adicionar Medicamento",
            style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        

      
    );
  }
}
