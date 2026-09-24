import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/printer_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../core/config/app_config.dart';
import '../../services/shop_service.dart';
import 'package:printing/printing.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isTestingConnection = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = AppConfig.backendUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleTestConnection() async {
    setState(() => _isTestingConnection = true);
    try {
      final shopService = ShopService();
      // Harmless authenticated request to verify connection
      await shopService.getShopQr();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connected to SecurePrint backend successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isTestingConnection = false);
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out of the SecurePrint Shop?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().logout();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final printerProvider = context.watch<PrinterProvider>();
    final dashboardProvider = context.watch<DashboardProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          
          // GENERAL SECTION
          _buildSectionTitle('General Configuration'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSettingRow(
                    'Environment',
                    DropdownButton<Environment>(
                      value: AppConfig.currentEnvironment,
                      items: Environment.values.map((env) {
                        return DropdownMenuItem(
                          value: env,
                          child: Text(env.name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (env) {
                        if (env != null) {
                          settingsProvider.setEnvironment(env);
                          _urlController.text = AppConfig.backendUrl; // Reset input field to default
                        }
                      },
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text('Backend URL', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'e.g. http://192.168.1.100:8000',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {
                          settingsProvider.setBackendUrl(_urlController.text);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Backend URL saved.')),
                          );
                        },
                        child: const Text('Save URL'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // PRINTER SECTION
          _buildSectionTitle('Printer Settings'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSettingRow(
                    'Preferred Printer',
                    printerProvider.selectedPrinter != null
                        ? Text(printerProvider.selectedPrinter!.name, style: const TextStyle(fontWeight: FontWeight.bold))
                        : const Text('None', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.print),
                    label: const Text('Change Printer'),
                    onPressed: () async {
                      final printer = await Printing.pickPrinter(context: context);
                      if (printer != null) {
                        printerProvider.selectPrinter(printer);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // DIAGNOSTICS SECTION
          _buildSectionTitle('Diagnostics'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSettingRow(
                    'Connection Status',
                    ElevatedButton.icon(
                      onPressed: _isTestingConnection ? null : _handleTestConnection,
                      icon: _isTestingConnection 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.wifi),
                      label: const Text('Test Connection'),
                    ),
                  ),
                  const Divider(),
                  _buildSettingRow(
                    'Detailed Logging',
                    Switch(
                      value: AppConfig.enableDetailedLogging,
                      onChanged: (val) => settingsProvider.toggleDetailedLogging(val),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // SESSION SECTION
          _buildSectionTitle('Session'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSettingRow(
                    'Logged-in Shop',
                    Text(dashboardProvider.shopProfile?.shopName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100, foregroundColor: Colors.red.shade900),
                    onPressed: _handleLogout,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ABOUT SECTION
          _buildSectionTitle('About'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSettingRow('Application', const Text('SecurePrint Shop Desktop', style: TextStyle(fontWeight: FontWeight.bold))),
                  _buildSettingRow('Version', const Text(AppConfig.version)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSettingRow(String label, Widget trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.black87)),
          trailing,
        ],
      ),
    );
  }
}
