import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../../models/print_job_detail_model.dart';
import '../../providers/print_execution_provider.dart';
import '../../providers/document_access_provider.dart';

class PrintExecutionDialog extends StatefulWidget {
  final PrintJobDetailModel job;
  final Printer printer;
  final String localFilePath;

  const PrintExecutionDialog({
    Key? key,
    required this.job,
    required this.printer,
    required this.localFilePath,
  }) : super(key: key);

  @override
  State<PrintExecutionDialog> createState() => _PrintExecutionDialogState();
}

class _PrintExecutionDialogState extends State<PrintExecutionDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrintExecutionProvider>().executePrint(
            widget.job,
            widget.printer,
            widget.localFilePath,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent dismissal by back button
      child: AlertDialog(
        title: const Text('Printing Status'),
        content: Consumer<PrintExecutionProvider>(
          builder: (context, provider, child) {
            switch (provider.state) {
              case PrintExecutionState.idle:
              case PrintExecutionState.starting:
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Updating server status...'),
                  ],
                );
              case PrintExecutionState.printing:
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Spooling copy ${provider.currentCopy} of ${widget.job.copies} to printer...'),
                  ],
                );
              case PrintExecutionState.syncing:
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Finalizing on server...'),
                  ],
                );
              case PrintExecutionState.completed:
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_circle, color: Colors.green, size: 48),
                    SizedBox(height: 16),
                    Text('Print job completed successfully!'),
                  ],
                );
              case PrintExecutionState.failed:
                final isSyncFailure = provider.errorMessage != null && provider.errorMessage!.contains('sync');
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(provider.errorMessage ?? 'An error occurred', style: const TextStyle(color: Colors.red)),
                    if (isSyncFailure) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'The physical print was sent, but updating the server failed. Please retry the sync to complete the job.',
                        textAlign: TextAlign.center,
                      ),
                    ]
                  ],
                );
            }
          },
        ),
        actions: [
          Consumer<PrintExecutionProvider>(
            builder: (context, provider, child) {
              if (provider.state == PrintExecutionState.failed) {
                final isSyncFailure = provider.errorMessage != null && provider.errorMessage!.contains('sync');
                if (isSyncFailure) {
                  return TextButton(
                    onPressed: () => provider.retrySync(),
                    child: const Text('Retry Sync'),
                  );
                } else {
                  return TextButton(
                    onPressed: () {
                      provider.reset();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Close'),
                  );
                }
              }

              if (provider.state == PrintExecutionState.completed) {
                return ElevatedButton(
                  onPressed: () async {
                    // Cleanup document access
                    await context.read<DocumentAccessProvider>().reset();
                    provider.reset();
                    // Pop dialog
                    Navigator.of(context).pop();
                    // Pop PrinterSelection
                    Navigator.of(context).pop();
                    // Pop DocumentPreview
                    Navigator.of(context).pop();
                  },
                  child: const Text('Finish'),
                );
              }

              return const SizedBox.shrink(); // Hide buttons while working
            },
          )
        ],
      ),
    );
  }
}
