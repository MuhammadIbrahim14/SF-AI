import 'package:flutter/material.dart';

class PaymentInvoiceDialog extends StatelessWidget {
  const PaymentInvoiceDialog({
    required this.transactionId,
    required this.paymentId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.description,
    super.key,
  });

  final String transactionId;
  final String paymentId;
  final double amount;
  final String currency;
  final String status;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Invoice', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text('Transaction: $transactionId'),
            Text('Payment: $paymentId'),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Amount'),
                Text('$currency ${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Status'),
                Chip(label: Text(status)),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
