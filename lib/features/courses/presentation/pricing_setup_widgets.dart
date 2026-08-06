import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/marketplace_models.dart';
import '../providers/purchase_provider.dart';

class PricingSetupDialog extends ConsumerStatefulWidget {
  const PricingSetupDialog({
    super.key,
    required this.courseId,
    required this.currentConfig,
    this.teacherId,
    this.onSuccess,
  });

  final String courseId;
  final PaidCourseConfig? currentConfig;
  final String? teacherId;
  final VoidCallback? onSuccess;

  @override
  ConsumerState<PricingSetupDialog> createState() => _PricingSetupDialogState();
}

class _PricingSetupDialogState extends ConsumerState<PricingSetupDialog> {
  late final TextEditingController priceController;
  late final TextEditingController discountController;
  late final TextEditingController thumbnailUrlController;

  String selectedCurrency = 'USD';
  bool isPaid = true;
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    final config = widget.currentConfig;
    priceController = TextEditingController(
      text: config?.isPaid == true ? config!.price.toStringAsFixed(2) : '0.00',
    );
    discountController = TextEditingController(
      text: config?.discount.toStringAsFixed(0) ?? '0',
    );
    thumbnailUrlController = TextEditingController(
      text: config?.thumbnailUrl ?? '',
    );
    selectedCurrency = config?.currency ?? 'USD';
    isPaid = config?.isPaid ?? false;
  }

  @override
  void dispose() {
    priceController.dispose();
    discountController.dispose();
    thumbnailUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleSetupPaidCourse() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final price = double.tryParse(priceController.text) ?? 0;
      final discount = double.tryParse(discountController.text) ?? 0;

      await ref.read(pricingSetupProvider.notifier).setupPaidCourse(
        courseId: widget.courseId,
        price: price,
        currency: selectedCurrency,
        discount: discount,
        thumbnailUrl: thumbnailUrlController.text.trim().isEmpty
            ? null
            : thumbnailUrlController.text,
        teacherId: widget.teacherId,
      );

      if (mounted) {
        widget.onSuccess?.call();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paid course setup successful')),
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final marketplaceConfig = ref.watch(marketplaceConfigProvider);

    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: marketplaceConfig.when(
            data: (config) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Setup Paid Course',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                if (errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      errorMessage!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Price Input
                TextField(
                  controller: priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText:
                        'Price (${config.minPrice} - ${config.maxPrice})',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Currency Selection
                DropdownButtonFormField<String>(
                  initialValue: selectedCurrency,
                  items: config.supportedCurrencies
                      .map((currency) => DropdownMenuItem(
                            value: currency,
                            child: Text(currency),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedCurrency = value;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Currency',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Discount Input
                TextField(
                  controller: discountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Discount (%)',
                    hintText: '0-100',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Thumbnail URL
                TextField(
                  controller: thumbnailUrlController,
                  decoration: InputDecoration(
                    labelText: 'Thumbnail URL (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: isLoading ? null : _handleSetupPaidCourse,
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Setup Paid Course'),
                    ),
                  ],
                ),
              ],
            ),
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, stack) => Text('Error: ${error.toString()}'),
          ),
        ),
      ),
    );
  }
}

class TeacherPricingCard extends ConsumerWidget {
  const TeacherPricingCard({
    super.key,
    required this.courseId,
    required this.isPremiumTeacher,
    this.teacherId,
    this.onEditPressed,
  });

  final String courseId;
  final bool isPremiumTeacher;
  final String? teacherId;
  final VoidCallback? onEditPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paidConfigAsync = ref.watch(paidCourseConfigProvider(courseId));

    if (!isPremiumTeacher) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paid Course',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Upgrade to a Pro teaching plan to enable paid courses.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onEditPressed,
                child: const Text('Upgrade to Premium'),
              ),
            ],
          ),
        ),
      );
    }

    return paidConfigAsync.when(
      data: (config) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Paid Course',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (config.isPaid)
                    Chip(
                      label: const Text('Paid'),
                      backgroundColor: Colors.green.withValues(alpha: 0.2),
                    )
                  else
                    Chip(
                      label: const Text('Free'),
                      backgroundColor: Colors.blue.withValues(alpha: 0.2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (config.isPaid) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Price: ${config.currency} ${config.price.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (config.hasDiscount)
                      Text(
                        'Discount: ${config.discount.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: Colors.green[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Final Price: ${config.currency} ${config.discountedPrice.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ] else ...[
                Text(
                  'This course is available for free enrollment',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onEditPressed ??
                    () {
                      showDialog(
                        context: context,
                        builder: (_) => PricingSetupDialog(
                          courseId: courseId,
                          currentConfig: config,
                          teacherId: teacherId,
                        ),
                      );
                    },
                icon: const Icon(Icons.edit),
                label: Text(config.isPaid ? 'Edit Pricing' : 'Configure Pricing'),
              ),
            ],
          ),
        ),
      ),
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: ${error.toString()}'),
        ),
      ),
    );
  }
}
