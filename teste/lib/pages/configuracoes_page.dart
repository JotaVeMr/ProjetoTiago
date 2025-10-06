import 'package:flutter/material.dart';

class ConfiguracoesPage extends StatelessWidget {
  final bool isDarkTheme;
  final ValueChanged<bool> onThemeChanged;

  const ConfiguracoesPage({
    super.key,
    required this.isDarkTheme,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text(
              'Personalização',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Tema escuro'),
              subtitle: const Text('Ativar ou desativar o modo escuro'),
              value: isDarkTheme,
              onChanged: (value) => onThemeChanged(value),
            ),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Sobre o aplicativo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Versão'),
              subtitle: Text('1.0.0'),
            ),
            const ListTile(
              leading: Icon(Icons.privacy_tip_outlined),
              title: Text('Política de privacidade'),
              subtitle:
                  Text('Leia sobre o uso de dados e permissões do aplicativo.'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isDarkTheme
          ? Container(
              color: Colors.grey[900],
              padding: const EdgeInsets.all(12),
              child: const Text(
                'Tema escuro ativado 🌙',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }
}
