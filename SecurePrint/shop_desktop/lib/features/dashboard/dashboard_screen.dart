import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/networking/api_client.dart';
import '../../providers/auth_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiClient _apiClient = ApiClient();
  String _backendStatus = "Checking...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkBackendStatus();
  }

  Future<void> _checkBackendStatus() async {
    try {
      final response = await _apiClient.get('/');
      setState(() {
        _backendStatus = "Connected: ${response['message'] ?? 'OK'}";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _backendStatus = "Error connecting to backend: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
            "SecurePrint Shop",
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            "Welcome to SecurePrint Shop Desktop",
            style: TextStyle(fontSize: 20, color: Colors.black87),
          ),
          const SizedBox(height: 32),
          _buildInfoCard(
            title: "Application Information",
            children: [
              _buildInfoRow("Version:", AppConfig.version),
              _buildInfoRow("Environment:", AppConfig.environmentName),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: "Backend Connection",
            children: [
              _buildInfoRow("Backend URL:", AppConfig.backendUrl),
              _buildInfoRow("Status:", _backendStatus, isLoading: _isLoading),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: "Authentication",
            children: [
              _buildInfoRow("Status:", "Authenticated"),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  context.read<AuthProvider>().logout();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    ));
  }

  Widget _buildInfoCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isLoading = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: isLoading
                ? Row(
                    children: [
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                      Text(value),
                    ],
                  )
                : Text(value),
          ),
        ],
      ),
    );
  }
}
