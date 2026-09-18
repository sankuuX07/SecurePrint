import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../../models/print_job_detail_model.dart';
import '../../providers/printer_provider.dart';

class PrinterSelectionScreen extends StatefulWidget {
  final PrintJobDetailModel job;
  final String localFilePath;

  const PrinterSelectionScreen({
    Key? key,
    required this.job,
    required this.localFilePath,
  }) : super(key: key);

  @override
  State<PrinterSelectionScreen> createState() => _PrinterSelectionScreenState();
}

class _PrinterSelectionScreenState extends State<PrinterSelectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrinterProvider>().loadPrinters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Printer - Job #${widget.job.id}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<PrinterProvider>().loadPrinters(),
            tooltip: 'Refresh Printers',
          ),
        ],
      ),
      body: Consumer<PrinterProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(provider.errorMessage!, style: const TextStyle(fontSize: 18, color: Colors.red)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => provider.loadPrinters(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.printers.isEmpty) {
            return const Center(
              child: Text('No printers were found.', style: TextStyle(fontSize: 18)),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Available Printers', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: provider.printers.length,
                    itemBuilder: (context, index) {
                      final printer = provider.printers[index];
                      final isSelected = provider.selectedPrinter?.name == printer.name;

                      return Card(
                        color: isSelected ? Colors.blue.shade50 : null,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: isSelected ? Colors.blue : Colors.transparent, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: Icon(Icons.print, color: isSelected ? Colors.blue : Colors.grey),
                          title: Text(printer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            printer.isDefault ? 'Windows Default Printer' : 
                            (printer.isAvailable ? 'Available' : 'Status unavailable'),
                          ),
                          trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blue) : null,
                          onTap: () => provider.selectPrinter(printer),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                const SizedBox(height: 16),
                const Text('Print Job Settings (Backend Authoritative)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Copies: ${widget.job.copies}'),
                Text('Color Mode: ${widget.job.colorMode}'),
                Text('Paper Size: ${widget.job.paperSize}'),
                Text('Print Side: ${widget.job.printSide}'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: provider.selectedPrinter != null ? () {
                      if (!provider.selectedPrinter!.isAvailable) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('The selected printer is currently unavailable.')),
                        );
                        return;
                      }

                      // M10 Placeholder
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Ready to Print'),
                          content: Text('M10 Placeholder:\n\nDocument authorized and printer "${provider.selectedPrinter!.name}" is selected. Actual printing will execute in M10.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            )
                          ],
                        )
                      );
                    } : null,
                    icon: const Icon(Icons.send),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text('Proceed to Print (M10)', style: TextStyle(fontSize: 18)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
