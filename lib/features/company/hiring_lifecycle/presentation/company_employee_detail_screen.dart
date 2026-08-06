import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/route_names.dart';
import '../../../../models/application_model.dart';
import '../../../../models/hiring_lifecycle_models.dart';
import '../../../../models/user_role.dart';
import '../../../../providers/application_provider.dart';
import '../../../../providers/company_provider.dart';
import '../../../../providers/job_provider.dart';
import '../../../../providers/pdf_export_provider.dart';
import '../../../../shared/widgets/role_fixed_header_page.dart';
import '../providers/hiring_lifecycle_providers.dart';
import 'widgets/employment_lifecycle_panels.dart';
import 'widgets/hiring_timeline_panel.dart';

class CompanyEmployeeDetailScreen extends ConsumerWidget {
  const CompanyEmployeeDetailScreen({super.key, required this.applicationId});

  final String applicationId;

  Future<void> _exportOfferPdf(
    BuildContext context,
    WidgetRef ref, {
    required ApplicationModel app,
    required String candidateName,
    required String jobTitle,
    required bool print,
  }) async {
    final company = ref.read(companyProvider).asData?.value;
    final companyName = (company?.companyName.trim().isNotEmpty == true)
        ? company!.companyName
        : 'Company';
    final ok = await ref.read(pdfExportActionProvider.notifier).exportOfferLetter(
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
                  : 'Offer letter ready to share.')
              : (ref.read(pdfExportActionProvider.notifier).errorMessage ??
                  'Unable to export offer letter.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appAsync = ref.watch(applicationDetailStreamProvider(applicationId));
    final theme = Theme.of(context);

    return RoleFixedHeaderPage(
      role: UserRole.company,
      title: 'Employee Details',
      subtitle: 'Offer, onboarding, welcome pack, HR, and lifecycle.',
      showBackButton: true,
      scrollable: false,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.companyEmployees),
      child: appAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (app) {
          if (app == null) {
            return const Center(child: Text('Application not found.'));
          }
          final userAsync = ref.watch(hiringUserProvider(app.applicantId));
          final jobAsync = ref.watch(jobDetailProvider(app.jobId));
          final name = userAsync.asData?.value?.fullName ??
              userAsync.asData?.value?.email ??
              app.applicantId;
          final jobTitle = jobAsync.asData?.value?.title ?? app.jobId;
          final busy = ref.watch(hiringLifecycleActionProvider).isLoading;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$jobTitle · ${employmentStatusLabel(app.employmentStatus)}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
                  ..._offerRows(app),
                  if (app.offerMessage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(app.offerMessage),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _exportOfferPdf(
                                  context,
                                  ref,
                                  app: app,
                                  candidateName: name,
                                  jobTitle: jobTitle,
                                  print: true,
                                ),
                        icon: const Icon(Icons.print_rounded),
                        label: const Text('Preview / Print'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: busy
                            ? null
                            : () => _exportOfferPdf(
                                  context,
                                  ref,
                                  app: app,
                                  candidateName: name,
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
              EmploymentInfoCard(
                title: 'HR notes (company only)',
                children: [
                  Text(
                    app.companyNotes.isEmpty
                        ? 'No private notes.'
                        : app.companyNotes,
                  ),
                  if (app.hrInterviewFeedback.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Interview feedback',
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(app.hrInterviewFeedback),
                  ],
                  if (app.hrHiringComments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Hiring comments',
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(app.hrHiringComments),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              EmploymentWelcomePackPanel(
                app: app,
                editable: !app.isLeftEmployee,
                busy: busy,
              ),
              const SizedBox(height: 12),
              EmploymentOnboardingChecklistPanel(
                app: app,
                asCandidate: false,
                busy: busy,
                readOnly: app.isLeftEmployee,
              ),
              const SizedBox(height: 12),
              EmploymentDocumentsPanel(
                app: app,
                asCandidate: false,
                busy: busy,
                readOnly: app.isLeftEmployee,
              ),
              const SizedBox(height: 12),
              EmploymentProbationPanel(
                app: app,
                companyActions: true,
                busy: busy,
              ),
              const SizedBox(height: 12),
              EmploymentOffboardingPanel(
                app: app,
                companyActions: true,
                busy: busy,
              ),
              const SizedBox(height: 12),
              EmploymentHrChatPanel(
                app: app,
                senderRole: 'company',
                readOnly: false,
              ),
              const SizedBox(height: 12),
              if (app.isJoiningSoon ||
                  app.normalizedOfferStatus == 'accepted') ...[
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          final ok = await ref
                              .read(hiringLifecycleActionProvider.notifier)
                              .markJoined(app.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Marked as active employee.'
                                    : (ref
                                            .read(
                                              hiringLifecycleActionProvider
                                                  .notifier,
                                            )
                                            .lastErrorMessage ??
                                        'Unable to mark joined.'),
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.badge_rounded),
                  label: const Text('Confirm Joined / Activate Employee'),
                ),
                const SizedBox(height: 16),
              ],
              HiringTimelinePanel(applicationId: app.id),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.pushNamed(
                  RouteNames.companyCandidateIntelligence,
                  pathParameters: {'applicationId': app.id},
                ),
                icon: const Icon(Icons.psychology_alt_rounded),
                label: const Text('Open Candidate Intelligence'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _offerRows(ApplicationModel app) {
    final rows = <MapEntry<String, String>>[
      if (app.offerRole.trim().isNotEmpty) MapEntry('Role', app.offerRole),
      if (app.offerDepartment.trim().isNotEmpty)
        MapEntry('Department', app.offerDepartment),
      if (app.offerSalary.trim().isNotEmpty)
        MapEntry(
          'Salary',
          '${app.offerSalary} ${app.offerCurrency}'.trim(),
        ),
      if (app.offerEmploymentType.trim().isNotEmpty)
        MapEntry('Employment', app.offerEmploymentType),
      if (app.offerJoiningDate.trim().isNotEmpty)
        MapEntry('Joining', app.offerJoiningDate),
      if (app.offerLocation.trim().isNotEmpty)
        MapEntry('Location', app.offerLocation),
      if (app.offerWorkingHours.trim().isNotEmpty)
        MapEntry('Hours', app.offerWorkingHours),
      if (app.offerContractDuration.trim().isNotEmpty)
        MapEntry('Contract', app.offerContractDuration),
      if (app.offerBenefits.trim().isNotEmpty)
        MapEntry('Benefits', app.offerBenefits),
      if (app.offerExpiresAt.trim().isNotEmpty)
        MapEntry('Expires', app.offerExpiresAt),
    ];
    if (rows.isEmpty) {
      return const [
        Text('No structured offer fields were filled for this hire.'),
      ];
    }
    return rows.map((e) => _row(e.key, e.value)).toList();
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
