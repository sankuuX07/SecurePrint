import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/shop_qr_provider.dart';

class ShopProfileScreen extends StatefulWidget {
  const ShopProfileScreen({Key? key}) : super(key: key);

  @override
  State<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends State<ShopProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShopQrProvider>().loadQr();
    });
  }

  void _handleRegenerate(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate Shop QR?'),
        content: const Text(
          'Regenerating the Shop Identity QR will revoke the previous QR. '
          'Customers using the old QR will no longer be able to identify this shop. '
          'Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ShopQrProvider>().regenerateQr();
            },
            child: const Text('Regenerate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<DashboardProvider>();
    final qrProvider = context.watch<ShopQrProvider>();
    final profile = profileProvider.shopProfile;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shop Profile & Identity',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Shop Information",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        const SizedBox(height: 16),
                        _buildInfoRow("Shop Name", profile?.shopName ?? profile?.name ?? 'N/A'),
                        _buildInfoRow("Email", profile?.email ?? 'N/A'),
                        _buildInfoRow("Phone", profile?.phone ?? 'N/A'),
                        _buildInfoRow("Address", profile?.address ?? 'N/A'),
                        _buildInfoRow("City", profile?.city ?? 'N/A'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                flex: 1,
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          "Shop Identity QR",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Customers can scan this QR to identify/select this shop.",
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        _buildQrSection(qrProvider, context),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  Widget _buildQrSection(ShopQrProvider qrProvider, BuildContext context) {
    if (qrProvider.state == ShopQrState.loading) {
      return const Padding(
        padding: EdgeInsets.all(48.0),
        child: CircularProgressIndicator(),
      );
    }

    if (qrProvider.state == ShopQrState.error || qrProvider.shopQr == null) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              qrProvider.errorMessage ?? "Shop Identity QR is currently unavailable.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => qrProvider.loadQr(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final qr = qrProvider.shopQr!;
    final isActive = qr.status == 'ACTIVE';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isActive ? Colors.green : Colors.red, width: 2),
          ),
          child: QrImageView(
            data: qr.qrIdentifier,
            version: QrVersions.auto,
            size: 200.0,
            foregroundColor: isActive ? Colors.black : Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Status: ", style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              qr.status,
              style: TextStyle(
                color: isActive ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "ID: ${qr.qrIdentifier}",
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 24),
        if (qrProvider.isRegenerating)
          const CircularProgressIndicator()
        else
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Regenerate QR'),
            onPressed: () => _handleRegenerate(context),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.black87,
              backgroundColor: Colors.grey.shade200,
            ),
          ),
      ],
    );
  }
}
