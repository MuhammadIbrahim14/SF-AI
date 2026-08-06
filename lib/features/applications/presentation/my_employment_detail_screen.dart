import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../models/application_model.dart';
import '../../../models/hiring_lifecycle_models.dart';
import '../../../models/user_role.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/pdf_export_provider.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../company/hiring_lifecycle/presentation/widgets/employment_lifecycle_panels.dart';
import '../../company/hiring_lifecycle/presentation/widgets/hiring_timeline_panel.dart';
import '../../company/hiring_lifecycle/providers/hiring_lifecycle_providers.dart';

class MyEmploymentDetailScreen extends ConsumerWidget {
  const MyEmploymentDetailScreen({super.key, required this.applicationId});

  final String applicationId;

  Future<void> _exportOffer(
    BuildContext context,
    WidgetRef ref, {
    required ApplicationModel app,
    required String jobTitle,
    required bool print,
  }) async {
    final company = await ref
        .read(companyRepositoryProvider)
        .getCompany(app.companyId);
    final companyName = (company?.companyName.trim().isNotEmpty == true)
        ? company!.companyName
        : 'Company';
    final user = ref.read(currentUserProvider).asData?.value;
    final candidateName = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName
        : (user?.email ?? 'Candidate');
    final ok = await ref
        .read(pdfExportActionProvider.notifier)
        .exportOfferLetter(
          application: app,
          companyName: companyName,
          candidateName: candidateName,
          jobTitle: jobTitle,
          print: print,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (print
                    ? 'Offer letter opened for print.'
                    : 'Offer letter ready.')
              : (ref.read(pdfExportActionProvider.notifier).errorMessage ??
                    'Unable to export offer letter.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appAsync = ref.watch(applicationDetailStreamProvider(applicationId));
    final currentRole =
        UserRole.fromString(
          ref.watch(currentUserProvider).value?.primaryRole,
        ) ??
        UserRole.freelancer;
    final theme = Theme.of(context);
    final busy = ref.watch(hiringLifecycleActionProvider).isLoading;

    return RoleFixedHeaderPage(
      role: currentRole,
      title: 'Employment details',
      subtitle: 'Offer, onboarding, welcome pack, and HR.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.myEmployment),
      scrollable: false,
      child: appAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (app) {
          if (app == null) {
            return const Center(child: Text('Employment record not found.'));
          }
          final jobAsync = ref.watch(jobDetailProvider(app.jobId));
          final jobTitle = jobAsync.asData?.value?.title ?? app.jobId;
          final readOnly = app.isLeftEmployee;
          final offerSalary = '${app.offerSalary} ${app.offerCurrency}'.trim();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                jobTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    avatar: Icon(
                      app.isActiveEmployee
                          ? Icons.verified_rounded
                          : app.isJoiningSoon
                          ? Icons.hourglass_top_rounded
                          : Icons.badge_outlined,
                      size: 18,
                    ),
                    label: Text(
                      app.isActiveEmployee
                          ? 'Active employee'
                          : employmentStatusLabel(app.employmentStatus),
                    ),
                  ),
                  if (app.displayDepartment.isNotEmpty)
                    Text(
                      app.displayDepartment,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              if (app.joinedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Joined ${DateFormat.yMMMd().format(app.joinedAt!)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              EmploymentInfoCard(
                title: 'Offer letter',
                children: [
                  if (app.offerRole.trim().isNotEmpty)
                    Text('Role: ${app.offerRole}'),
                  if (app.offerDepartment.trim().isNotEmpty)
                    Text('Department: ${app.offerDepartment}'),
                  if (app.offerSalary.trim().isNotEmpty)
                    Text('Salary: $offerSalary'),
                  if (app.offerEmploymentType.trim().isNotEmpty)
                    Text('Employment: ${app.offerEmploymentType}'),
                  if (app.offerJoiningDate.trim().isNotEmpty)
                    Text('Joining: ${app.offerJoiningDate}'),
                  if (app.offerLocation.trim().isNotEmpty)
                    Text('Location: ${app.offerLocation}'),
                  if (app.offerWorkingHours.trim().isNotEmpty)
                    Text('Hours: ${app.offerWorkingHours}'),
                  if (app.offerContractDuration.trim().isNotEmpty)
                    Text('Contract: ${app.offerContractDuration}'),
                  if (app.offerBenefits.trim().isNotEmpty)
                    Text('Benefits: ${app.offerBenefits}'),
                  if (app.offerExpiresAt.trim().isNotEmpty)
                    Text('Expires: ${app.offerExpiresAt}'),
                  if (app.offerMessage.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(app.offerMessage),
                  ],
                  if (app.offerRole.isEmpty &&
                      app.offerSalary.isEmpty &&
                      app.offerJoiningDate.isEmpty &&
                      app.offerMessage.isEmpty)
                    const Text(
                      'Your offer letter PDF has the full details — use Preview below.',
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _exportOffer(
                                context,
                                ref,
                                app: app,
                                jobTitle: jobTitle,
                                print: true,
                              ),
                        icon: const Icon(Icons.print_rounded),
                        label: const Text('Preview / Print'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: busy
                            ? null
                            : () => _exportOffer(
                                context,
                                ref,
                                app: app,
                                jobTitle: jobTitle,
                                print: false,
                              ),
                        icon: const Icon(Icons.ios_share_rounded),
                        label: const Text('Share PDF'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              EmploymentWelcomePackPanel(app: app, editable: false),
              const SizedBox(height: 12),
              EmploymentOnboardingChecklistPanel(
                app: app,
                asCandidate: true,
                busy: busy,
                readOnly: readOnly,
              ),
              const SizedBox(height: 12),
              EmploymentDocumentsPanel(
                app: app,
                asCandidate: true,
                busy: busy,
                readOnly: readOnly,
              ),
              const SizedBox(height: 12),
              EmploymentProbationPanel(app: app, companyActions: false),
              const SizedBox(height: 12),
              EmploymentOffboardingPanel(app: app, companyActions: false),
              const SizedBox(height: 12),
              EmploymentHrChatPanel(
                app: app,
                senderRole: 'candidate',
                readOnly: readOnly,
              ),
              const SizedBox(height: 12),
              HiringTimelinePanel(applicationId: app.id),
            ],
          );
        },
      ),
    );
  }
}
