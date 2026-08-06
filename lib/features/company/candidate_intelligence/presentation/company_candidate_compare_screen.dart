import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/application_model.dart';
import '../../../../models/user_role.dart';
import '../../../../providers/application_provider.dart';
import '../../../../providers/company_permission_provider.dart';
import '../../../../providers/repository_providers.dart';
import '../../../../shared/widgets/role_fixed_header_page.dart';
import '../models/company_candidate_intelligence_models.dart';
import '../providers/company_candidate_intelligence_providers.dart';

class CompanyCandidateCompareScreen extends ConsumerStatefulWidget {
  const CompanyCandidateCompareScreen({
    required this.jobId,
    this.initialApplicationIds = const [],
    super.key,
  });

  final String jobId;
  final List<String> initialApplicationIds;

  @override
  ConsumerState<CompanyCandidateCompareScreen> createState() =>
      _CompanyCandidateCompareScreenState();
}

class _CompanyCandidateCompareScreenState
    extends ConsumerState<CompanyCandidateCompareScreen> {
  final _selected = <String>{};
  final _names = <String, String>{};
  List<CompanyCandidateComparisonRow>? _rows;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initialApplicationIds);
  }

  Future<void> _resolveNames(List<ApplicationModel> apps) async {
    final users = ref.read(userRepositoryProvider);
    for (final a in apps) {
      if (_names.containsKey(a.id)) continue;
      try {
        final u = await users.getUser(a.applicantId);
        _names[a.id] = u?.fullName ?? a.applicantId;
      } catch (_) {
        _names[a.id] = a.applicantId;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _compare() async {
    if (_selected.length < 2) {
      setState(() => _error = 'Select at least two candidates.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _rows = null;
    });
    final rows = await ref
        .read(companyCandidateIntelligenceActionProvider.notifier)
        .compare(
          jobId: widget.jobId,
          applicationIds: _selected.toList(),
        );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (rows == null) {
        _error = ref
                .read(companyCandidateIntelligenceActionProvider.notifier)
                .lastErrorMessage ??
            'AI comparison unavailable.';
      } else {
        _rows = rows;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(jobApplicationsProvider(widget.jobId));
    final permission = ref.watch(companyPermissionProvider).value;

    return RoleFixedHeaderPage(
      role: UserRole.company,
      title: 'AI Candidate Compare',
      subtitle: 'Unlimited selection · advisory recommendation only',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(
              RouteNames.jobApplicants,
              pathParameters: {'id': widget.jobId},
            ),
      child: permission?.canViewApplicants != true
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Company verification required.'),
            )
          : appsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (apps) {
                // ignore: discarded_futures
                _resolveNames(apps);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Select candidates',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 8),
                      for (final a in apps)
                        CheckboxListTile(
                          value: _selected.contains(a.id),
                          title: Text(_names[a.id] ?? a.applicantId),
                          subtitle: Text(
                            pipelineStageLabel(a.normalizedPipelineStage),
                          ),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selected.add(a.id);
                              } else {
                                _selected.remove(a.id);
                              }
                            });
                          },
                        ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _loading ? null : _compare,
                        icon: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.compare_arrows),
                        label: Text(_loading ? 'Comparing…' : 'AI Compare'),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],
                      if (_rows != null) ...[
                        const SizedBox(height: 20),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Candidate')),
                              DataColumn(label: Text('Technical')),
                              DataColumn(label: Text('Communication')),
                              DataColumn(label: Text('Confidence')),
                              DataColumn(label: Text('Portfolio')),
                              DataColumn(label: Text('Projects')),
                              DataColumn(label: Text('Certs')),
                              DataColumn(label: Text('Interview')),
                              DataColumn(label: Text('Recommendation')),
                            ],
                            rows: [
                              for (final r in _rows!)
                                DataRow(
                                  cells: [
                                    DataCell(
                                      InkWell(
                                        onTap: () => context.pushNamed(
                                          RouteNames
                                              .companyCandidateIntelligence,
                                          pathParameters: {
                                            'applicationId': r.applicationId,
                                          },
                                        ),
                                        child: Text(
                                          r.candidateName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.companyPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(r.technical.toStringAsFixed(0)),
                                    ),
                                    DataCell(
                                      Text(r.communication.toStringAsFixed(0)),
                                    ),
                                    DataCell(
                                      Text(r.confidence.toStringAsFixed(0)),
                                    ),
                                    DataCell(
                                      Text(r.portfolioScore.toStringAsFixed(0)),
                                    ),
                                    DataCell(
                                      Text(r.projectsScore.toStringAsFixed(0)),
                                    ),
                                    DataCell(Text('${r.certificatesCount}')),
                                    DataCell(
                                      Text(r.interviewScore.toStringAsFixed(0)),
                                    ),
                                    DataCell(Text(r.overallRecommendation)),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}
