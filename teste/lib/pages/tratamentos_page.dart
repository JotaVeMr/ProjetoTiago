// lib/pages/tratamentos_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medicamento.dart';
import '../models/usuario.dart';
import '../services/database_helper.dart';
import '../services/app_event_bus.dart';
import 'add_medicamento_page.dart';

class TratamentosPage extends StatefulWidget {
  @override
  _TratamentosPageState createState() => _TratamentosPageState();
}

class _TratamentosPageState extends State<TratamentosPage> {
  Usuario? usuarioSelecionado;
  List<Medicamento> medicamentos = [];

  @override
  void initState() {
    super.initState();
    _loadUsuarioSelecionado().then((_) => _loadMedicamentos());
  }

  Future<void> _loadUsuarioSelecionado() async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioJson = prefs.getString('usuarioSelecionado');
    if (usuarioJson != null) {
      usuarioSelecionado = Usuario.fromMap(jsonDecode(usuarioJson));
    } else {
      usuarioSelecionado = null;
    }
    setState(() {});
  }

  // Carrega os medicamentos salvos (SharedPreferences + SQLite) por usuário
  Future<void> _loadMedicamentos() async {
    if (usuarioSelecionado == null || usuarioSelecionado!.id == null) {
      setState(() => medicamentos = []);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('medicamentos_${usuarioSelecionado!.id}') ?? [];
    List<Medicamento> prefsList =
        data.map((e) => Medicamento.fromJson(jsonDecode(e))).toList();

    final dbList = await DatabaseHelper.instance
        .getMedicamentos(usuarioId: usuarioSelecionado!.id!);

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

    await _syncToStorage();
  }

  Future<void> _syncToStorage() async {
    if (usuarioSelecionado == null || usuarioSelecionado!.id == null) return;

    final prefs = await SharedPreferences.getInstance();

    // sync para db (garante usuarioId)
    for (final med in medicamentos) {
      med.usuarioId = usuarioSelecionado!.id;
      if (med.id != null) {
        await DatabaseHelper.instance.updateMedicamento(med);
      } else {
        final newId = await DatabaseHelper.instance.insertMedicamento(med);
        if (newId != 0) med.id = newId;
      }
    }

    // salvar em prefs por usuário
    await prefs.setStringList(
      'medicamentos_${usuarioSelecionado!.id}',
      medicamentos.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  // Abre a tela para adicionar/editar medicamento
  void _navigateToAddMedicamentoPage({Medicamento? medicamento, int? index}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMedicamentoPage(
          medicamento: medicamento,
          index: index,
        ),
      ),
    );
    if (result == true) {
      await _loadMedicamentos();
      AppEventBus.I.bumpMedChange(); // avisa Home
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
                await _syncToStorage();
                AppEventBus.I.bumpMedChange(); // avisa Home para recarregar
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final nome = usuarioSelecionado?.nome ?? 'Perfil';

    return Scaffold(
      appBar: AppBar(
        title: Text("Tratamentos — $nome"),
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
                "${med.tipo} - ${med.dose} - "
                "${med.scheduledDateTime.toLocal().toString().split(' ')[0]} "
                "${med.scheduledTimeOfDay.format(context)}",
                style: const TextStyle(color: Colors.grey),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _navigateToAddMedicamentoPage(
                      medicamento: med,
                      index: index,
                    ),
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
