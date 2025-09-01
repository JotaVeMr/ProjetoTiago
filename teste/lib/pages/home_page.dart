import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/medicamento.dart';
import '../services/notification_service.dart';
import 'add_medicamento_page.dart';

// Página Inicial
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Medicamento> medicamentos = [];
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadMedicamentos();
  }

  // Carrega os medicamentos salvos (usando SharedPreferences)
  Future<void> _loadMedicamentos() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('medicamentos') ?? [];
    setState(() {
      medicamentos = data
          .map((e) => Medicamento.fromJson(jsonDecode(e)))
          .toList();
      medicamentos.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));
    });
  }

  // Salva os medicamentos (usando SharedPreferences)
  Future<void> _saveMedicamentos() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(
        'medicamentos', medicamentos.map((e) => jsonEncode(e.toJson())).toList());
  }

  // Filtra os medicamentos para o dia selecionado
  List<Medicamento> _getMedicamentosForSelectedDay(DateTime day) {
    return medicamentos.where((med) {
      return isSameDay(med.scheduledDateTime, day);
    }).toList();
  }

  // Abre a tela para adicionar medicamento e recarrega a lista
  void _navigateToAddMedicamentoPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddMedicamentoPage()),
    );
    if (result == true) {
      _loadMedicamentos();
    }
  }

  // ==== Lógica para o pop-up de ação do medicamento ====
  void _showMedicamentoActions(Medicamento medicamento, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bc) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
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
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                Text(
                  "Tomar ${medicamento.dose}",
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        medicamento.isTaken = true;
                        medicamento.isIgnored = false;
                      });
                      _saveMedicamentos();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${medicamento.nome} marcado como tomado!')),
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
                        medicamento.dataHoraAgendamento = newScheduledDateTime.toIso8601String();
                        medicamento.isTaken = false;
                        medicamento.isIgnored = false;
                      });
                      _saveMedicamentos();
                      NotificationService().scheduleNotification(
                        medicamento.id ?? newScheduledDateTime.millisecondsSinceEpoch % 100000,
                        "Hora do medicamento",
                        "É hora de tomar ${medicamento.nome} - ${medicamento.dose}",
                        newScheduledDateTime,
                      );
                      _loadMedicamentos();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${medicamento.nome} reagendado para ${new TimeOfDay(hour: newScheduledDateTime.hour, minute: newScheduledDateTime.minute).format(context)}')),
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
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        medicamento.isTaken = false;
                        medicamento.isIgnored = true;
                      });
                      _saveMedicamentos();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${medicamento.nome} ignorado.')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: Colors.blue),
                    ),
                    child: const Text("Ignorar", style: TextStyle(fontSize: 18)),
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
    final medicamentosForSelectedDay = _selectedDay != null
        ? _getMedicamentosForSelectedDay(_selectedDay!)
        : [];

    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            children: <TextSpan>[
              TextSpan(
                text: 'pharm',
                style: TextStyle(color: Colors.blue),
              ),
              TextSpan(
                text: 'Sync',
                style: TextStyle(color: Colors.black),
              ),
            ],
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
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
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
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
              return _getMedicamentosForSelectedDay(day);
            },
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
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            med.nome,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${med.tipo} - ${med.dose} - ${med.scheduledTimeOfDay.format(context)}",
                                style: const TextStyle(color: Colors.grey),
                              ),
                              if (med.isTaken)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    "Tomado",
                                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              if (med.isIgnored)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    "Ignorado",
                                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                  ),
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
        label: const Text("Adicionar Medicamento", style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}