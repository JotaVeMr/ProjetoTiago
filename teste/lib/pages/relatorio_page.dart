import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class RelatorioPage extends StatefulWidget {
  const RelatorioPage({Key? key}) : super(key: key);

  @override
  State<RelatorioPage> createState() => _RelatorioPageState();
}

class _RelatorioPageState extends State<RelatorioPage> {
  List<Map<String, dynamic>> _relatorio = [];
  bool _loading = true;
  String _filtroSelecionado = '7';
  int? _usuarioSelecionado;
  List<Map<String, dynamic>> _usuarios = [];

  int _totalTomado = 0;
  int _totalNaoTomado = 0;

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
  }

  Future<void> _carregarUsuarios() async {
    final usuarios = await DatabaseHelper.instance.getUsuarios();
    setState(() {
      _usuarios = usuarios
          .map((u) => {
                'id': u.id,
                'nome': "${u.nome} ${u.sobrenome}".trim(),
              })
          .toList();

      if (_usuarios.isNotEmpty) {
        _usuarioSelecionado = _usuarios.first['id'];
      }
    });

    await _carregarRelatorio();
  }

  Future<void> _carregarRelatorio() async {
    setState(() => _loading = true);

    
    await DatabaseHelper.instance.marcarPendentesComoNaoTomados();

    final db = await DatabaseHelper.instance.database;

    String filtroQuery = '';
    if (_filtroSelecionado == '7') {
      filtroQuery = "AND D.horarioConfirmacao >= datetime('now', '-7 days')";
    } else if (_filtroSelecionado == '30') {
      filtroQuery = "AND D.horarioConfirmacao >= datetime('now', '-30 days')";
    }

    String filtroUsuario = '';
    List<dynamic> args = [];
    if (_usuarioSelecionado != null) {
      filtroUsuario = 'AND M.usuarioId = ?';
      args.add(_usuarioSelecionado);
    }

    final result = await db.rawQuery('''
      SELECT 
        M.nome AS medicamento,
        D.horarioConfirmacao,
        COALESCE(D.status, '') AS status
      FROM dose_confirmada D
      JOIN medicamentos M ON D.medicamentoId = M.id
      WHERE 1=1
        $filtroUsuario
        $filtroQuery
      ORDER BY D.horarioConfirmacao DESC
    ''', args);

    int tomados = 0;
    int naoTomados = 0;

    for (var r in result) {
      final status = (r['status'] ?? '').toString().toUpperCase().trim();
      if (status == 'TOMADO') {
        tomados++;
      } else {
        naoTomados++;
      }
    }

    setState(() {
      _relatorio = result;
      _totalTomado = tomados;
      _totalNaoTomado = naoTomados;
      _loading = false;
    });
  }

  Color _statusColor(String status) {
    return status.toUpperCase() == 'TOMADO' ? Colors.green : Colors.red;
  }

  IconData _statusIcon(String status) {
    return status.toUpperCase() == 'TOMADO'
        ? Icons.check_circle
        : Icons.cancel;
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalTomado + _totalNaoTomado;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Relatórios de Doses"),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      DropdownButtonFormField<int>(
                        value: _usuarioSelecionado,
                        decoration: const InputDecoration(
                          labelText: 'Selecione o perfil',
                          border: OutlineInputBorder(),
                        ),
                        items: _usuarios
                            .map<DropdownMenuItem<int>>((u) {
                          return DropdownMenuItem<int>(
                            value: u['id'] as int,
                            child: Text(u['nome'] as String),
                          );
                        }).toList(),
                        onChanged: (value) async {
                          setState(() => _usuarioSelecionado = value);
                          await _carregarRelatorio();
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _filtroSelecionado,
                        decoration: const InputDecoration(
                          labelText: 'Período',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: '7', child: Text('Últimos 7 dias')),
                          DropdownMenuItem(
                              value: '30', child: Text('Últimos 30 dias')),
                          DropdownMenuItem(
                              value: 'todos', child: Text('Todos os registros')),
                        ],
                        onChanged: (value) async {
                          setState(() => _filtroSelecionado = value!);
                          await _carregarRelatorio();
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(),

                
                if (total > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 160,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 45,
                                  sections: [
                                    PieChartSectionData(
                                      color: Colors.green,
                                      value: _totalTomado.toDouble(),
                                      title: '',
                                      radius: 45,
                                    ),
                                    PieChartSectionData(
                                      color: Colors.red,
                                      value: _totalNaoTomado.toDouble(),
                                      title: '',
                                      radius: 45,
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    "Total",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    "$total doses",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.circle, color: Colors.green, size: 14),
                            SizedBox(width: 4),
                            Text("Tomados  "),
                            Icon(Icons.circle, color: Colors.red, size: 14),
                            SizedBox(width: 4),
                            Text("Não Tomados"),
                          ],
                        ),
                        const SizedBox(height: 8),

                        Text(
                          "Tomados: $_totalTomado | Não Tomados: $_totalNaoTomado",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),

                const Divider(),

                Expanded(
                  child: _relatorio.isEmpty
                      ? const Center(
                          child: Text(
                            "Nenhum registro encontrado neste período.",
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _relatorio.length,
                          itemBuilder: (context, index) {
                            final item = _relatorio[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: ListTile(
                                leading: Icon(
                                  _statusIcon(item['status']),
                                  color: _statusColor(item['status']),
                                ),
                                title: Text(item['medicamento']),
                                subtitle: Text(
                                  'Status: ${item['status']}\n'
                                  'Data: ${DateFormat("dd/MM/yyyy HH:mm").format(DateTime.parse(item['horarioConfirmacao']))}',
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
