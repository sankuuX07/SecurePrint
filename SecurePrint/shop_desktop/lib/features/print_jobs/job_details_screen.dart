import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_detail_provider.dart';
import '../../models/print_job_detail_model.dart';
import '../../models/payment_model.dart';
import 'secure_qr_scanner_screen.dart';

class JobDetailsScreen extends StatelessWidget {
  final int jobId;
  final VoidCallback onBack;

  const JobDetailsScreen({Key? key, required this.jobId, required this.onBack}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => JobDetailProvider(jobId: jobId)..loadJob(),
      child: _JobDetailsContent(onBack: onBack),
    );
  }
}

class _JobDetailsContent extends StatelessWidget {
  final VoidCallback onBack;

  const _JobDetailsContent({Key? key, required this.onBack}) : super(key: key);

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMM d, yyyy h:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
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
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
    );
  }

  void _handleMarkPaid(BuildContext context, JobDetailProvider provider, double amount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text('Confirm that the customer has paid ₹${amount.toStringAsFixed(2)} at the shop?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.markPaymentPaid();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JobDetailProvider>();

    if (provider.state == JobDetailState.unauthorized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<AuthProvider>().logout();
      });
      return const SizedBox.shrink();
    }

    if (provider.state == JobDetailState.loading || provider.state == JobDetailState.initial) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.state == JobDetailState.error) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                provider.errorMessage ?? 'Failed to load job details',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onBack,
                child: const Text('Back to Print Jobs'),
              ),
            ],
          ),
        ),
      );
    }

    final job = provider.jobDetail!;
    final payment = provider.payment;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: Text('Job #${job.id} Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.loadJob(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (provider.errorMessage != null && provider.state == JobDetailState.loaded)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade100,
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(provider.errorMessage!, style: const TextStyle(color: Colors.red))),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusChip(job.status),
                  Row(
                    children: [
                      if (job.status == 'CREATED' || job.status == 'SENT_TO_SHOP')
                        ElevatedButton.icon(
                          onPressed: provider.isActionProcessing ? null : () => provider.acceptJob(),
                          icon: provider.isActionProcessing 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.check),
                          label: const Text('Accept Job'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        ),
                      if (job.status == 'ACCEPTED')
                        ElevatedButton.icon(
                          onPressed: provider.isActionProcessing ? null : () => provider.startJob(),
                          icon: provider.isActionProcessing 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.print),
                          label: const Text('Start Printing'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                        ),
                      if (job.status == 'PRINTING')
                        ElevatedButton.icon(
                          onPressed: provider.isActionProcessing ? null : () => provider.completeJob(),
                          icon: provider.isActionProcessing 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.done_all),
                          label: const Text('Complete Job'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        ),
                      if (job.status == 'ACCEPTED' || job.status == 'PRINTING') ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SecureQrScannerScreen(job: job),
                              ),
                            );
                          },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Scan QR'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Job Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Divider(),
                    _InfoRow('Document ID:', job.documentId),
                    _InfoRow('Created:', _formatDate(job.createdAt)),
                    _InfoRow('Price:', '₹${job.price.toStringAsFixed(2)}'),
                    if (payment != null) ...[
                      _InfoRow('Payment Method:', payment.method),
                      _InfoRow('Payment Status:', payment.status),
                      if (payment.paidAt != null)
                        _InfoRow('Paid At:', _formatDate(payment.paidAt)),
                      if (payment.method == 'PAY_AT_SHOP' && payment.status == 'UNPAID')
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: ElevatedButton.icon(
                            onPressed: provider.isActionProcessing
                                ? null
                                : () => _handleMarkPaid(context, provider, payment.amount),
                            icon: const Icon(Icons.payments),
                            label: const Text('Mark as Paid'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Print Configuration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Divider(),
                    _InfoRow('Copies:', job.copies.toString()),
                    _InfoRow('Paper Size:', job.paperSize),
                    _InfoRow('Color Mode:', job.colorMode),
                    _InfoRow('Print Side:', job.printSide),
                    if (job.selectedPageCount != null)
                      _InfoRow('Pages to Print:', job.selectedPageCount.toString()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Divider(),
                    if (job.statusHistory.isEmpty)
                      const Text('No history available.')
                    else
                      ...job.statusHistory.map((h) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Text(_formatDate(h.changedAt), style: const TextStyle(color: Colors.grey)),
                            const SizedBox(width: 16),
                            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                            const SizedBox(width: 16),
                            Text(h.toStatus, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
