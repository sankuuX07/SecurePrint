import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/print_jobs_provider.dart';
import '../../models/print_job_model.dart';
import 'package:intl/intl.dart';
import '../print_jobs/job_details_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
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

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Job History',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  const Text('Filter Status: '),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: provider.selectedStatus ?? 'ALL',
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All')),
                      DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                      DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                      DropdownMenuItem(value: 'PRINTING', child: Text('Printing')),
                      DropdownMenuItem(value: 'ACCEPTED', child: Text('Accepted')),
                    ],
                    onChanged: (value) {
                      provider.setFilter(value == 'ALL' ? null : value);
                    },
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _handleRefresh,
                    tooltip: 'Refresh History',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: provider.state == PrintJobsState.loading
                ? const Center(child: CircularProgressIndicator())
                : provider.state == PrintJobsState.error
                    ? Center(
                        child: Text(
                          provider.errorMessage ?? 'Error loading history',
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                        ),
                      )
                    : provider.jobs.isEmpty
                        ? const Center(
                            child: Text(
                              'No print jobs found.',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          )
                        : Card(
                            elevation: 2,
                            child: Column(
                              children: [
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: provider.jobs.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final job = provider.jobs[index];
                                      return _buildJobTile(context, job);
                                    },
                                  ),
                                ),
                                _buildPagination(provider),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobTile(BuildContext context, PrintJobModel job) {
    String dateStr = 'Unknown';
    if (job.createdAt != null) {
      try {
        final dt = DateTime.parse(job.createdAt!).toLocal();
        dateStr = DateFormat('MMM d, yyyy h:mm a').format(dt);
      } catch (_) {}
    }

    return ListTile(
      title: Text('Job #${job.id}'),
      subtitle: Text('$dateStr • ${job.copies} copies • ₹${job.price.toStringAsFixed(2)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusChip(job.status),
          const SizedBox(width: 16),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobDetailsScreen(jobId: job.id),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'CREATED':
      case 'SENT_TO_SHOP':
        color = Colors.orange;
        break;
      case 'ACCEPTED':
        color = Colors.blue;
        break;
      case 'PRINTING':
        color = Colors.purple;
        break;
      case 'COMPLETED':
        color = Colors.green;
        break;
      case 'CANCELLED':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildPagination(PrintJobsProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Page ${provider.currentPage}'),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: provider.currentPage > 1 ? () => provider.previousPage() : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: provider.hasNextPage ? () => provider.nextPage() : null,
          ),
        ],
      ),
    );
  }
}
