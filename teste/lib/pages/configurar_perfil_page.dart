import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

import '../models/usuario.dart';
import '../services/database_helper.dart';
import '../main.dart' as app; //  usado para voltar ao MyApp após criar perfil

class ConfigurarPerfilPage extends StatefulWidget {
  const ConfigurarPerfilPage({super.key});

  @override
  State<ConfigurarPerfilPage> createState() => _ConfigurarPerfilPageState();
}

class _ConfigurarPerfilPageState extends State<ConfigurarPerfilPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _sobrenomeCtrl = TextEditingController();

  Sexo _sexo = Sexo.outro;
  List<Usuario> _usuarios = [];
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadUsuarios();
  }

  Future<void> _loadUsuarios() async {
    final list = await DatabaseHelper.instance.getUsuarios();
    setState(() => _usuarios = list);
  }

  Future<void> _salvarUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    final novo = Usuario(
      nome: _nomeCtrl.text.trim(),
      sobrenome: _sobrenomeCtrl.text.trim(),
      sexo: _sexo,
      pin: '', 
      id: null,
    );

    final id = await DatabaseHelper.instance.insertUsuario(novo);
    if (id != 0) {
      final criado = novo.copyWith(id: id);
      setState(() => _usuarios.add(criado));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('usuarioSelecionado', jsonEncode(criado.toMap()));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil salvo e selecionado!')),
      );

      _nomeCtrl.clear();
      _sobrenomeCtrl.clear();
      setState(() => _sexo = Sexo.outro);

      
      final isDarkTheme = prefs.getBool('isDarkTheme') ?? false;

      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => app.MyApp(
            onboardingDone: true,
            isDarkTheme: isDarkTheme,
          ),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _selecionarUsuario(Usuario u) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('usuarioSelecionado', jsonEncode(u.toMap()));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  
  Future<bool> _autenticarLocalmente() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final available = await _localAuth.getAvailableBiometrics();

      debugPrint('=== LOCAL AUTH DEBUG ===');
      debugPrint('isSupported: $isSupported');
      debugPrint('canCheckBiometrics: $canCheck');
      debugPrint('availableBiometrics: $available');
      debugPrint('=========================');

      if (!isSupported) {
        debugPrint('Dispositivo não suporta autenticação local.');
        return true; // permite se não for suportado
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Confirme sua identidade para remover o perfil.',
        options: const AuthenticationOptions(
          biometricOnly: false, // permite PIN/padrão do sistema
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );

      debugPrint('Resultado da autenticação: $didAuthenticate');
      return didAuthenticate;
    } catch (e) {
      debugPrint('Erro na autenticação local: $e');
      return false;
    }
  }

  Future<void> _removerUsuario(Usuario u) async {
    final autenticado = await _autenticarLocalmente();
    if (!autenticado) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Autenticação falhou.')),
      );
      return;
    }

    final confirma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover perfil'),
        content: Text('Tem certeza que deseja remover o perfil "${u.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirma != true) return;

    await DatabaseHelper.instance.deleteUsuario(u.id!);

    final prefs = await SharedPreferences.getInstance();
    final sel = prefs.getString('usuarioSelecionado');
    if (sel != null) {
      final map = jsonDecode(sel) as Map<String, dynamic>;
      if ((map['id'] as int?) == u.id) {
        await prefs.remove('usuarioSelecionado');
      }
    }

    await _loadUsuarios();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil removido com sucesso.')),
    );

    if (_usuarios.isEmpty) {
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _sobrenomeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar perfil'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Adicionar novo perfil',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nomeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sobrenomeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Sobrenome (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Sexo',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Sexo>(
                        isExpanded: true,
                        value: _sexo,
                        items: const [
                          DropdownMenuItem(
                              value: Sexo.masculino, child: Text('Masculino')),
                          DropdownMenuItem(
                              value: Sexo.feminino, child: Text('Feminino')),
                          DropdownMenuItem(value: Sexo.outro, child: Text('Outro')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _sexo = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _nomeCtrl.clear();
                            _sobrenomeCtrl.clear();
                            setState(() => _sexo = Sexo.outro);
                          },
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _salvarUsuario,
                          child: const Text('Salvar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Perfis cadastrados',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_usuarios.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Nenhum perfil cadastrado.')),
              ),
            ..._usuarios.map((u) {
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      u.nome.isNotEmpty
                          ? u.nome.characters.first.toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(u.nome),
                  subtitle: Text([
                    if (u.sobrenome.trim().isNotEmpty) u.sobrenome,
                    sexoToString(u.sexo),
                  ].join(' • ')),
                  onTap: () => _selecionarUsuario(u),
                  trailing: IconButton(
                    tooltip: 'Remover perfil',
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removerUsuario(u),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
