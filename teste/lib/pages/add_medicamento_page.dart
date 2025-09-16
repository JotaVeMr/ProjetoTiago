// lib/pages/add_medicamento_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medicamento.dart';
import '../services/notification_service.dart';
import '../services/database_helper.dart'; // 🔹 para usar SQLite

// Página para adicionar ou editar medicamento
class AddMedicamentoPage extends StatefulWidget {
  final Medicamento? medicamento;
  final int? index;

  const AddMedicamentoPage({super.key, this.medicamento, this.index});

  @override
  _AddMedicamentoPageState createState() => _AddMedicamentoPageState();
}

class _AddMedicamentoPageState extends State<AddMedicamentoPage> {
  final nomeController = TextEditingController();
  final doseController = TextEditingController();
  String tipoSelecionado = "Comprimido";
  TimeOfDay horarioSelecionado = TimeOfDay.now();

  // NOVOS: data de início e fim do tratamento
  DateTime dataInicioSelecionada = DateTime.now();
  DateTime dataFimSelecionada = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    if (widget.medicamento != null) {
      nomeController.text = widget.medicamento!.nome;
      tipoSelecionado = widget.medicamento!.tipo;
      doseController.text = widget.medicamento!.dose;

      // restaurar horário
      try {
        horarioSelecionado = widget.medicamento!.scheduledTimeOfDay;
      } catch (_) {
        horarioSelecionado = TimeOfDay.now();
      }

      // restaurar dataInicio/dataFim
      try {
        if (widget.medicamento!.dataInicio.isNotEmpty) {
          dataInicioSelecionada = DateTime.parse(widget.medicamento!.dataInicio);
        }
      } catch (_) {
        dataInicioSelecionada = DateTime.now();
      }
      try {
        if (widget.medicamento!.dataFim.isNotEmpty) {
          dataFimSelecionada = DateTime.parse(widget.medicamento!.dataFim);
        }
      } catch (_) {
        dataFimSelecionada = DateTime.now().add(const Duration(days: 7));
      }
    }
  }

  // Salva o medicamento no banco e no SharedPreferences
  Future<void> _saveMedicamento() async {
    if (nomeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, preencha o nome do medicamento.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (doseController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, preencha a dose do medicamento.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Monta a primeira data de agendamento (início + horário)
    final fullDateTime = DateTime(
      dataInicioSelecionada.year,
      dataInicioSelecionada.month,
      dataInicioSelecionada.day,
      horarioSelecionado.hour,
      horarioSelecionado.minute,
    );

    final med = Medicamento(
      id: widget.medicamento?.id ?? DateTime.now().millisecondsSinceEpoch,
      nome: nomeController.text,
      tipo: tipoSelecionado,
      dose: doseController.text,
      dataHoraAgendamento: fullDateTime.toIso8601String(),
      dataInicio: dataInicioSelecionada.toIso8601String(),
      dataFim: dataFimSelecionada.toIso8601String(),
      isTaken: widget.medicamento?.isTaken ?? false,
      isIgnored: widget.medicamento?.isIgnored ?? false,
      isPendente: widget.medicamento?.isPendente ?? false,
    );

    // 🔹 Salvar no SQLite
    final db = await DatabaseHelper.instance.database;
    if (widget.medicamento != null && widget.medicamento!.id != null) {
      await db.update(
        'medicamentos',
        med.toMap(),
        where: 'id = ?',
        whereArgs: [widget.medicamento!.id],
      );
    } else {
      await db.insert('medicamentos', med.toMap());
    }

    // 🔹 Salvar também no SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final List<String> listaAtualizadaJson =
        prefs.getStringList('medicamentos') ?? [];
    List<Medicamento> listaAtualizada = listaAtualizadaJson
        .map((e) => Medicamento.fromJson(jsonDecode(e)))
        .toList();

    if (widget.index != null && widget.index! < listaAtualizada.length) {
      listaAtualizada[widget.index!] = med;
    } else {
      listaAtualizada.add(med);
    }

    await prefs.setStringList(
      'medicamentos',
      listaAtualizada.map((e) => jsonEncode(e.toJson())).toList(),
    );

    // 🔹 Agendar notificação
    NotificationService().scheduleNotification(
      med.id!,
      "Hora do medicamento",
      "É hora de tomar ${med.nome} - ${med.dose}",
      fullDateTime,
    );

    Navigator.pop(context, true);
  }

  // 🔹 Função helper para abrir calendário
  Future<void> _selecionarData({
    required DateTime dataAtual,
    required ValueChanged<DateTime> onDateSelected,
    DateTime? minDate,
    DateTime? maxDate,
  }) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: dataAtual,
      firstDate: minDate ?? DateTime.now().subtract(const Duration(days: 365)),
      lastDate: maxDate ?? DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.medicamento != null
            ? "Editar Medicamento"
            : "Adicionar Medicamento"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(
                labelText: "Nome do Medicamento",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: tipoSelecionado,
              decoration: const InputDecoration(
                labelText: "Tipo",
                border: OutlineInputBorder(),
              ),
              items: ["Comprimido", "Dose", "Cápsula", "Xarope"]
                  .map((tipo) => DropdownMenuItem(
                        value: tipo,
                        child: Text(tipo),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  tipoSelecionado = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: doseController,
              decoration: const InputDecoration(
                labelText: "Quantidade/Dosagem",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 16),

            // 🔹 Campo Data de Início
            TextField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: "Início do Tratamento",
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.calendar_today),
              ),
              controller: TextEditingController(
                text: dateFormat.format(dataInicioSelecionada),
              ),
              onTap: () => _selecionarData(
                dataAtual: dataInicioSelecionada,
                onDateSelected: (picked) {
                  setState(() {
                    dataInicioSelecionada = picked;
                    if (dataFimSelecionada.isBefore(dataInicioSelecionada)) {
                      dataFimSelecionada =
                          dataInicioSelecionada.add(const Duration(days: 7));
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // 🔹 Campo Data de Fim
            TextField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: "Fim do Tratamento",
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.calendar_today),
              ),
              controller: TextEditingController(
                text: dateFormat.format(dataFimSelecionada),
              ),
              onTap: () => _selecionarData(
                dataAtual: dataFimSelecionada,
                minDate: dataInicioSelecionada,
                onDateSelected: (picked) {
                  setState(() {
                    dataFimSelecionada = picked;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Horário
            TextField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: "Horário",
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.access_time),
              ),
              controller: TextEditingController(
                text: horarioSelecionado.format(context),
              ),
              onTap: () async {
                final TimeOfDay? hora = await showTimePicker(
                  context: context,
                  initialTime: horarioSelecionado,
                );
                if (hora != null) {
                  setState(() {
                    horarioSelecionado = hora;
                  });
                }
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveMedicamento,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(widget.medicamento != null
                  ? "Salvar Alterações"
                  : "Adicionar Medicamento"),
            ),
          ],
        ),
      ),
    );
  }
}
