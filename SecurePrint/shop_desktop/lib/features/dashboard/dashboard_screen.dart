import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/print_job_model.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboard();
    });
  }

  void _handleRefresh() {
    context.read<DashboardProvider>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();

    if (provider.state == DashboardState.unauthorized) {
      // Defer state change to next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<AuthProvider>().logout();
      });
      return const SizedBox.shrink();
    }

    if (provider.state == DashboardState.initial || provider.state == DashboardState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.state == DashboardState.error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              provider.errorMessage ?? 'An error occurred',
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _handleRefresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final profile = provider.shopProfile;
    final jobs = provider.recentJobs;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Welcome, ${profile?.shopName ?? profile?.name ?? 'Shop'}",
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _handleRefresh,
                tooltip: 'Refresh Dashboard',
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Statistics Row
          Row(
            children: [
              _buildStatCard('Pending', provider.pendingJobsCount, Colors.orange),
              const SizedBox(width: 16),
              _buildStatCard('Accepted', provider.acceptedJobsCount, Colors.blue),
              const SizedBox(width: 16),
              _buildStatCard('Printing', provider.printingJobsCount, Colors.purple),
              const SizedBox(width: 16),
              _buildStatCard('Completed', provider.completedJobsCount, Colors.green),
              const SizedBox(width: 16),
              _buildStatCard('Cancelled', provider.cancelledJobsCount, Colors.red),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Shop Profile Information
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Shop Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  _buildInfoRow("Email", profile?.email ?? 'N/A'),
                  _buildInfoRow("Phone", profile?.phone ?? 'N/A'),
                  _buildInfoRow("Address", profile?.address ?? 'N/A'),
                  _buildInfoRow("City", profile?.city ?? 'N/A'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Recent Jobs List
          const Text("Recent Print Jobs", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildRecentJobsTable(jobs),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildRecentJobsTable(List<PrintJobModel> jobs) {
    if (jobs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(
            child: Text(
              "No print jobs yet.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: jobs.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final job = jobs[index];
          String dateStr = 'Unknown';
          if (job.createdAt != null) {
            try {
              final dt = DateTime.parse(job.createdAt!).toLocal();
              dateStr = DateFormat('MMM d, yyyy h:mm a').format(dt);
            } catch (_) {}
          }
          
          return ListTile(
            title: Text('Job #${job.id}'),
            subtitle: Text('$dateStr • ${job.copies} copies • ${job.paperSize} ${job.colorMode}'),
            trailing: _buildStatusChip(job.status),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'CREATED':
      case 'SENT_TO_SHOP':
        color = Colors.orange;
        label = 'Pending';
        break;
      case 'ACCEPTED':
        color = Colors.blue;
        label = 'Accepted';
        break;
      case 'PRINTING':
        color = Colors.purple;
        label = 'Printing';
        break;
      case 'COMPLETED':
        color = Colors.green;
        label = 'Completed';
        break;
      case 'CANCELLED':
        color = Colors.red;
        label = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      padding: const EdgeInsets.all(0),
    );
  }
}
