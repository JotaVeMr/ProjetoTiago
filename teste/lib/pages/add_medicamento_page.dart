 import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medicamento.dart';
import '../services/notification_service.dart';

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
  DateTime dataSelecionada = DateTime.now();
  TimeOfDay horarioSelecionado = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    if (widget.medicamento != null) {
      nomeController.text = widget.medicamento!.nome;
      tipoSelecionado = widget.medicamento!.tipo;
      doseController.text = widget.medicamento!.dose;
      dataSelecionada = widget.medicamento!.scheduledDateTime;
      horarioSelecionado = widget.medicamento!.scheduledTimeOfDay;
    }
  }

  // Salva o medicamento e agenda a notificação
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

    final fullDateTime = DateTime(
      dataSelecionada.year,
      dataSelecionada.month,
      dataSelecionada.day,
      horarioSelecionado.hour,
      horarioSelecionado.minute,
    );

    final int newId = widget.medicamento?.id ?? DateTime.now().millisecondsSinceEpoch;

    final med = Medicamento(
      id: newId,
      nome: nomeController.text,
      tipo: tipoSelecionado,
      dose: doseController.text,
      dataHoraAgendamento: fullDateTime.toIso8601String(),
    );

    final prefs = await SharedPreferences.getInstance();
    final List<String> listaAtualizadaJson = prefs.getStringList('medicamentos') ?? [];
    List<Medicamento> listaAtualizada = listaAtualizadaJson
        .map((e) => Medicamento.fromJson(jsonDecode(e)))
        .toList();

    if (widget.index != null && widget.index! < listaAtualizada.length) {
      listaAtualizada[widget.index!] = med;
    } else {
      listaAtualizada.add(med);
    }
    
    await prefs.setStringList(
        'medicamentos', listaAtualizada.map((e) => jsonEncode(e.toJson())).toList());

    NotificationService().scheduleNotification(
      med.id!,
      "Hora do medicamento",
      "É hora de tomar ${med.nome} - ${med.dose}",
      fullDateTime,
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
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
            ListTile(
              title: Text("Data: ${dataSelecionada.toLocal().toString().split(' ')[0]}"),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: dataSelecionada,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                );
                if (picked != null && picked != dataSelecionada) {
                  setState(() {
                    dataSelecionada = picked;
                  });
                }
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text("Horário: ${horarioSelecionado.format(context)}"),
              trailing: const Icon(Icons.access_time),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Colors.grey),
              ),
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
              child: Text(widget.medicamento != null ? "Salvar Alterações" : "Adicionar Medicamento"),
            ),
          ],
        ),
      ),
    );
  }
}