import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_helper.dart';

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

          //  personalização
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

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),

          // ☁️ Backup e Restauração
          _buildSectionTitle('Backup e restauração', theme),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup_outlined, color: Colors.blueAccent),
                  title: const Text(
                    'Fazer backup local',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Gera um arquivo .json com todos os dados do aplicativo.'),
                  onTap: () async {
                    final path = await DatabaseHelper.instance.exportarBackup();

                    if (!context.mounted) return;

                    
                    // ScaffoldMessenger.of(context).showSnackBar(
                    //   const SnackBar(
                    //     content: Text('Arquivo de backup gerado. Escolha onde salvar.'),
                    //     duration: Duration(seconds: 2),
                    //   ),
                    // );

                    
                    await Share.shareXFiles([XFile(path)], text: 'Backup do PharmSync');
                  },

                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore_page_outlined, color: Colors.green),
                  title: const Text(
                    'Restaurar backup',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Importa os dados de um arquivo de backup .json.'),
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['json'],
                    );

                    if (result != null && result.files.single.path != null) {
                      await DatabaseHelper.instance.importarBackup(result.files.single.path!);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Backup restaurado com sucesso!')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),

          //  Reinicializar aplicativo
          _buildSectionTitle('Gerenciamento', theme),
          Card(
            color: Colors.red.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.restart_alt, color: Colors.redAccent),
              title: const Text(
                'Reinicializar aplicativo',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
              ),
              subtitle: const Text(
                'Apaga todos os dados e volta às configurações iniciais.',
              ),
              onTap: () => _confirmarReinicio(context),
            ),
          ),

          const SizedBox(height: 32),

          
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

  Future<void> _confirmarReinicio(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reinicializar aplicativo'),
        content: const Text(
          'Tem certeza de que deseja apagar todos os dados e voltar às configurações iniciais?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final db = DatabaseHelper.instance;
    await db.resetDatabase();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Aplicativo reiniciado com sucesso!'),
        duration: Duration(seconds: 3),
      ),
    );

    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }
}
