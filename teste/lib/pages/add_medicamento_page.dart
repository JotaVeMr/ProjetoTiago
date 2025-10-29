// lib/pages/add_medicamento_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medicamento.dart';
import '../models/usuario.dart';
import '../services/notification_service.dart';
import '../services/database_helper.dart';

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

  DateTime dataInicioSelecionada = DateTime.now();
  DateTime dataFimSelecionada = DateTime.now().add(const Duration(days: 7));

  Usuario? _usuarioSelecionado;

  @override
  void initState() {
    super.initState();
    _carregarUsuarioSelecionado();

    if (widget.medicamento != null) {
      nomeController.text = widget.medicamento!.nome;
      tipoSelecionado = widget.medicamento!.tipo;
      doseController.text = widget.medicamento!.dose;

      try {
        horarioSelecionado = widget.medicamento!.scheduledTimeOfDay;
      } catch (_) {
        horarioSelecionado = TimeOfDay.now();
      }

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

  Future<void> _carregarUsuarioSelecionado() async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioJson = prefs.getString('usuarioSelecionado');
    if (usuarioJson != null) {
      setState(() {
        _usuarioSelecionado = Usuario.fromJson(jsonDecode(usuarioJson));
      });
    }
  }

  Future<void> _saveMedicamento() async {
    if (_usuarioSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um perfil antes de adicionar.')),
      );
      return;
    }
    if (nomeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha o nome do medicamento.'), backgroundColor: Colors.red),
      );
      return;
    }
    if (doseController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha a dose do medicamento.'), backgroundColor: Colors.red),
      );
      return;
    }

    final fullDateTime = DateTime(
      dataInicioSelecionada.year,
      dataInicioSelecionada.month,
      dataInicioSelecionada.day,
      horarioSelecionado.hour,
      horarioSelecionado.minute,
    );

    //Escolher tipo de notificação
    String? tipoNotificacao = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Escolha o tipo de notificação'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'nao_notificar'),
              child: const Text('Não notificar'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'no_horario'),
              child: const Text('No horário'),
            ),
          
          ],
        );
      },
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
      usuarioId: _usuarioSelecionado!.id,
    );

    // SQLite
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

    // SharedPreferences (por usuário)
    final prefs = await SharedPreferences.getInstance();
    final key = 'medicamentos_${_usuarioSelecionado!.id}';
    final List<String> listaAtualizadaJson = prefs.getStringList(key) ?? [];
    List<Medicamento> listaAtualizada =
        listaAtualizadaJson.map((e) => Medicamento.fromJson(jsonDecode(e))).toList();

    if (widget.index != null && widget.index! < listaAtualizada.length) {
      listaAtualizada[widget.index!] = med;
    } else {
      listaAtualizada.add(med);
    }

    await prefs.setStringList(
      key,
      listaAtualizada.map((e) => jsonEncode(e.toJson())).toList(),
    );

    
    if (tipoNotificacao != null && tipoNotificacao != 'nao_notificar') {
      DateTime horarioNotificacao = fullDateTime;
      if (tipoNotificacao == 'adiantado') {
        horarioNotificacao = horarioNotificacao.subtract(const Duration(minutes: 10));
      } else if (tipoNotificacao == 'atrasado') {
        horarioNotificacao = horarioNotificacao.add(const Duration(minutes: 10));
      }

        NotificationService().scheduleNotification(
          med.id! % 1000000000, 
          "Hora do medicamento",
          "É hora de tomar ${med.nome} - ${med.dose}",
          fullDateTime,
        );
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.medicamento != null ? "Editar Medicamento" : "Adicionar Medicamento"),
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
                  .map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo)))
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

            // Início
            ListTile(
              title: Text("Início do Tratamento: ${DateFormat('dd/MM/yyyy').format(dataInicioSelecionada)}"),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: dataInicioSelecionada,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                );
                if (picked != null) {
                  setState(() {
                    dataInicioSelecionada = picked;
                    if (dataFimSelecionada.isBefore(dataInicioSelecionada)) {
                      dataFimSelecionada = dataInicioSelecionada.add(const Duration(days: 7));
                    }
                  });
                }
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),

            // Fim
            ListTile(
              title: Text("Fim do Tratamento: ${DateFormat('dd/MM/yyyy').format(dataFimSelecionada)}"),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: dataFimSelecionada,
                  firstDate: dataInicioSelecionada,
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                );
                if (picked != null) {
                  setState(() {
                    dataFimSelecionada = picked;
                  });
                }
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),

            // Horário
            ListTile(
              title: Text("Horário: ${horarioSelecionado.format(context)}"),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final hora = await showTimePicker(
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(widget.medicamento != null ? "Salvar Alterações" : "Adicionar Medicamento"),
            ),
          ],
        ),
      ),
    );
  }
}
