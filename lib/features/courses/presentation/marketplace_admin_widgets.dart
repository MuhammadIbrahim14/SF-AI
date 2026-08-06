import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/marketplace_models.dart';
import '../providers/purchase_provider.dart';

class MarketplaceSettingsDialog extends ConsumerStatefulWidget {
  const MarketplaceSettingsDialog({super.key, 
    required this.onSuccess,
  });

  final VoidCallback? onSuccess;

  @override
  ConsumerState<MarketplaceSettingsDialog> createState() =>
      _MarketplaceSettingsDialogState();
}

class _MarketplaceSettingsDialogState
    extends ConsumerState<MarketplaceSettingsDialog> {
  late TextEditingController minPriceController;
  late TextEditingController maxPriceController;
  late TextEditingController commissionController;

  bool paidCoursesEnabled = true;
  List<String> selectedCurrencies = [];
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    minPriceController = TextEditingController();
    maxPriceController = TextEditingController();
    commissionController = TextEditingController();
  }

  @override
  void dispose() {
    minPriceController.dispose();
    maxPriceController.dispose();
    commissionController.dispose();
    super.dispose();
  }

  void _loadCurrentSettings(MarketplaceConfig config) {
    minPriceController.text = config.minPrice.toStringAsFixed(2);
    maxPriceController.text = config.maxPrice.toStringAsFixed(2);
    commissionController.text = config.platformCommissionPercent.toStringAsFixed(1);
    paidCoursesEnabled = config.paidCoursesEnabled;
    selectedCurrencies = List.from(config.supportedCurrencies);
  }

  Future<void> _saveSettings() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final minPrice = double.tryParse(minPriceController.text) ?? 0;
      final maxPrice = double.tryParse(maxPriceController.text) ?? 999.99;
      final commission = double.tryParse(commissionController.text) ?? 20;

      if (minPrice >= maxPrice) {
        setState(() {
          errorMessage = 'Minimum price must be less than maximum price';
        });
        return;
      }

      final updatedConfig = MarketplaceConfig(
        minPrice: minPrice,
        maxPrice: maxPrice,
        supportedCurrencies: selectedCurrencies,
        paidCoursesEnabled: paidCoursesEnabled,
        platformCommissionPercent: commission,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref
          .read(coursePurchaseRepositoryProvider)
          .updateMarketplaceConfig(updatedConfig);

      // Invalidate cache
      ref.invalidate(marketplaceConfigProvider);

      if (mounted) {
        widget.onSuccess?.call();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marketplace settings updated')),
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
    final configAsync = ref.watch(marketplaceConfigProvider);

    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: configAsync.when(
            data: (config) {
              // Initialize fields on first load
              if (minPriceController.text.isEmpty) {
                _loadCurrentSettings(config);
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marketplace Settings',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  // Feature Toggle
                  SwitchListTile(
                    title: const Text('Enable Paid Courses'),
                    subtitle:
                        const Text('Allow teachers to create paid courses'),
                    value: paidCoursesEnabled,
                    onChanged: (value) {
                      setState(() {
                        paidCoursesEnabled = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Price Range
                  TextField(
                    controller: minPriceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Minimum Price',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: maxPriceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Maximum Price',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Commission
                  TextField(
                    controller: commissionController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Platform Commission (%)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Currencies
                  Text(
                    'Supported Currencies',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      'USD',
                      'EUR',
                      'GBP',
                      'PKR',
                      'INR',
                    ]
                        .map((currency) => FilterChip(
                              label: Text(currency),
                              selected: selectedCurrencies.contains(currency),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    selectedCurrencies.add(currency);
                                  } else {
                                    selectedCurrencies.remove(currency);
                                  }
                                });
                              },
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  // Error message
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
                        onPressed: isLoading ? null : _saveSettings,
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save Settings'),
                      ),
                    ],
                  ),
                ],
              );
            },
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

class MarketplaceOverviewCard extends ConsumerWidget {
  const MarketplaceOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(marketplaceConfigProvider);

    return configAsync.when(
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
                    'Marketplace Configuration',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Chip(
                    label: Text(
                      config.paidCoursesEnabled ? 'Enabled' : 'Disabled',
                    ),
                    backgroundColor: config.paidCoursesEnabled
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.red.withValues(alpha: 0.2),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ConfigRow(
                label: 'Price Range',
                value: '\$${config.minPrice.toStringAsFixed(2)} - \$${config.maxPrice.toStringAsFixed(2)}',
              ),
              _ConfigRow(
                label: 'Platform Commission',
                value: '${config.platformCommissionPercent.toStringAsFixed(1)}%',
              ),
              _ConfigRow(
                label: 'Supported Currencies',
                value: config.supportedCurrencies.join(', '),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => MarketplaceSettingsDialog(
                      onSuccess: () {
                        ref.invalidate(marketplaceConfigProvider);
                      },
                    ),
                  );
                },
                icon: const Icon(Icons.settings),
                label: const Text('Configure Marketplace'),
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

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

// Admin Sales Overview
class AdminSalesOverview extends ConsumerWidget {
  const AdminSalesOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Marketplace Statistics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _StatRow(
              icon: Icons.shopping_cart,
              label: 'Total Paid Courses',
              ref: ref,
              provider: allPaidCoursesProvider,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends ConsumerWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.ref,
    required this.provider,
  });

  final IconData icon;
  final String label;
  final WidgetRef ref;
  final FutureProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(provider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          dataAsync.when(
            data: (data) {
              final count = data is List ? data.length : 0;
              return Text(
                count.toString(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              );
            },
            loading: () => const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (error, stack) => const Text('Error'),
          ),
        ],
      ),
    );
  }
}
