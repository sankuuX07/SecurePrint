import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/print_jobs_provider.dart';
import '../../models/print_job_model.dart';
import 'job_details_screen.dart';

class PrintJobsScreen extends StatefulWidget {
  const PrintJobsScreen({Key? key}) : super(key: key);

  @override
  State<PrintJobsScreen> createState() => _PrintJobsScreenState();
}

class _PrintJobsScreenState extends State<PrintJobsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrintJobsProvider>().loadJobs(reset: true);
    });
  }

  void _handleRefresh() {
    context.read<PrintJobsProvider>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrintJobsProvider>();

    if (provider.state == PrintJobsState.unauthorized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<AuthProvider>().logout();
      });
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Print Jobs",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _handleRefresh,
                tooltip: 'Refresh Print Jobs',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildFilters(provider),
          const SizedBox(height: 16),
          Expanded(
            child: _buildContent(provider),
          ),
          const SizedBox(height: 16),
          _buildPaginationControls(provider),
        ],
      ),
    );
  }

  Widget _buildFilters(PrintJobsProvider provider) {
    final statuses = [
      'ALL',
      'CREATED',
      'SENT_TO_SHOP',
      'ACCEPTED',
      'PRINTING',
      'COMPLETED',
      'CANCELLED'
    ];

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: statuses.map((status) {
        final isSelected = (provider.selectedStatus == status) || 
                           (provider.selectedStatus == null && status == 'ALL');
        return FilterChip(
          label: Text(status),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              provider.setFilter(status == 'ALL' ? null : status);
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildContent(PrintJobsProvider provider) {
    if (provider.state == PrintJobsState.initial || provider.state == PrintJobsState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.state == PrintJobsState.error) {
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

    if (provider.jobs.isEmpty) {
      return Center(
        child: Text(
          provider.selectedStatus == null 
              ? "No print jobs found." 
              : "No jobs match the selected filter.",
          style: const TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: ListView.separated(
        itemCount: provider.jobs.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final job = provider.jobs[index];
          return _buildJobRow(job);
        },
      ),
    );
  }

  Widget _buildJobRow(PrintJobModel job) {
    String dateStr = 'Unknown date';
    if (job.createdAt != null) {
      try {
        final dt = DateTime.parse(job.createdAt!).toLocal();
        dateStr = DateFormat('MMM d, yyyy h:mm a').format(dt);
      } catch (_) {}
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobDetailsScreen(
              jobId: job.id,
              onBack: () => Navigator.pop(context),
            ),
          ),
        ).then((_) {
          // Refresh list when returning
          if (context.mounted) {
            context.read<PrintJobsProvider>().refresh();
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Job #${job.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(dateStr, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${job.copies} Copies • ${job.paperSize} ${job.colorMode}'),
                  const SizedBox(height: 4),
                  Text(job.printSide),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                '\$${job.price.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: _buildStatusChip(job.status),
              ),
            ),
          ],
        ),
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
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildPaginationControls(PrintJobsProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: provider.currentPage > 1 ? () => provider.previousPage() : null,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Previous'),
        ),
        const SizedBox(width: 16),
        Text('Page ${provider.currentPage}'),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: provider.hasNextPage ? () => provider.nextPage() : null,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Next'),
        ),
      ],
    );
  }
}
