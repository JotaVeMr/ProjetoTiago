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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        centerTitle: true,
        elevation: 2,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          // 🔧 Seção de personalização
          _buildSectionTitle('Personalização', theme),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              secondary: Icon(
                Icons.dark_mode_rounded,
                color: isDarkTheme
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              title: const Text(
                'Tema escuro',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Ativar ou desativar o modo escuro'),
              value: isDarkTheme,
              activeColor: theme.colorScheme.primary,
              onChanged: (value) => onThemeChanged(value),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),

          // 💊 Seção sobre o aplicativo
          _buildSectionTitle('Sobre o aplicativo', theme),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.info_outline, color: Colors.blueAccent),
                  title: Text('Versão'),
                  subtitle: Text('1.0.0'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.privacy_tip_outlined, color: Colors.green),
                  title: Text('Política de privacidade'),
                  subtitle: Text(
                    'Leia sobre o uso de dados e permissões do aplicativo.',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 💡 Novo card: Dicas de uso
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const ListTile(
              leading: Icon(Icons.lightbulb_outline, color: Colors.amber),
              title: Text('Dicas de uso'),
              subtitle: Text(
                'Mantenha seus lembretes sempre atualizados e revise as datas '
                'dos tratamentos periodicamente para evitar esquecimentos.',
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ❤️ Assinatura visual
          Center(
            child: Text(
              'PharmSync • Cuidando da sua rotina 💊',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
