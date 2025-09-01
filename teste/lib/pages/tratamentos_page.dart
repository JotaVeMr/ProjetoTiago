 import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medicamento.dart';
import 'add_medicamento_page.dart';

// Página de Tratamentos (editar/excluir/adicionar)
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

  // Carrega os medicamentos salvos
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

  // Salva os medicamentos (usado após adicionar/editar/excluir)
  Future<void> _saveMedicamentos() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(
        'medicamentos', medicamentos.map((e) => jsonEncode(e.toJson())).toList());
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
  void _deleteMedicamento(int index) {
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
              onPressed: () {
                setState(() {
                  medicamentos.removeAt(index);
                  _saveMedicamentos();
                });
                Navigator.of(context).pop();
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