// lib/pages/tratamentos_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medicamento.dart';
import '../services/database_helper.dart';
import 'add_medicamento_page.dart';

class TratamentosPage extends StatefulWidget {
  @override
  _TratamentosPageState createState() => _TratamentosPageState();
}

class _TratamentosPageState extends State<TratamentosPage> {
  List<Medicamento> medicamentos = [];

  @override
  void initState() {
    super.initState();
    _loadMedicamentos();
  }

  // Carrega os medicamentos salvos (SharedPreferences + SQLite)
  Future<void> _loadMedicamentos() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('medicamentos') ?? [];
    List<Medicamento> prefsList = data.map((e) => Medicamento.fromJson(jsonDecode(e))).toList();

    final dbList = await DatabaseHelper.instance.getMedicamentos();

    final Map<String, Medicamento> mapa = {};
    for (final m in prefsList) {
      final key = m.id != null ? 'id_${m.id}' : 'pref_${m.nome}_${m.dataHoraAgendamento}';
      mapa[key] = m;
    }
    for (final m in dbList) {
      final key = m.id != null ? 'id_${m.id}' : 'db_${m.nome}_${m.dataHoraAgendamento}';
      mapa[key] = m;
    }

    setState(() {
      medicamentos = mapa.values.toList();
      medicamentos.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));
    });

    // sincroniza (garante que DB e prefs fiquem iguais)
    await _syncToStorage();
  }

  Future<void> _syncToStorage() async {
    final prefs = await SharedPreferences.getInstance();

    // sync para db
    for (final med in medicamentos) {
      if (med.id != null) {
        await DatabaseHelper.instance.updateMedicamento(med);
      } else {
        final newId = await DatabaseHelper.instance.insertMedicamento(med);
        if (newId != 0) med.id = newId;
      }
    }

    // salvar em prefs
    await prefs.setStringList('medicamentos', medicamentos.map((e) => jsonEncode(e.toJson())).toList());
  }

  // Salva os medicamentos (usado após adicionar/editar/excluir)
  Future<void> _saveMedicamentos() async {
    await _syncToStorage();
  }

  // Abre a tela para adicionar/editar medicamento
  void _navigateToAddMedicamentoPage({Medicamento? medicamento, int? index}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => AddMedicamentoPage(
                medicamento: medicamento,
                index: index,
              )),
    );
    if (result == true) {
      _loadMedicamentos();
    }
  }

  // Confirmação e exclusão de medicamento
  void _deleteMedicamento(int index) async {
    final med = medicamentos[index];
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Excluir Medicamento"),
          content: const Text("Tem certeza que deseja excluir este medicamento?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text("Excluir", style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop();
                if (med.id != null) {
                  await DatabaseHelper.instance.deleteMedicamento(med.id!);
                }
                setState(() {
                  medicamentos.removeAt(index);
                });
                await _saveMedicamentos();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Meus Tratamentos"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView.builder(
        itemCount: medicamentos.length,
        itemBuilder: (context, index) {
          final med = medicamentos[index];
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
              subtitle: Text(
                "${med.tipo} - ${med.dose} - ${med.scheduledDateTime.toLocal().toString().split(' ')[0]} ${med.scheduledTimeOfDay.format(context)}",
                style: const TextStyle(color: Colors.grey),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _navigateToAddMedicamentoPage(medicamento: med, index: index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteMedicamento(index),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddMedicamentoPage(),
        label: const Text("Adicionar Medicamento", style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
