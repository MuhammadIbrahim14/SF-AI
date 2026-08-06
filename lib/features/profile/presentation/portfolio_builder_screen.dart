import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/public_profile_model.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../providers/public_profile_provider.dart';

class PortfolioBuilderScreen extends ConsumerStatefulWidget {
  const PortfolioBuilderScreen({super.key});

  @override
  ConsumerState<PortfolioBuilderScreen> createState() =>
      _PortfolioBuilderScreenState();
}

class _PortfolioBuilderScreenState
    extends ConsumerState<PortfolioBuilderScreen> {
  final _slugController = TextEditingController();
  final _headlineController = TextEditingController();
  final _bioController = TextEditingController();
  bool _publish = false;
  bool _seeded = false;

  @override
  void dispose() {
    _slugController.dispose();
    _headlineController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draftAsync = ref.watch(publicProfileDraftProvider);
    final saved = ref.watch(myPublicProfileProvider).value;
    final portfolioSettings =
        ref.watch(portfolioSettingsProvider).asData?.value ??
        const PortfolioSettings(
          portfolioBaseUrl: PortfolioSettings.defaultPortfolioBaseUrl,
          isPortfolioEnabled: true,
        );
    final actionState = ref.watch(publicProfileActionProvider);

    return draftAsync.when(
      loading: () => const RoleFixedHeaderPage(
        role: UserRole.student,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => RoleFixedHeaderPage(
        role: UserRole.student,
        title: 'Portfolio Builder',
        child: Center(child: Text('Unable to load builder: $error')),
      ),
      data: (draft) {
        final profile = saved ?? draft;
        _seed(profile);
        final role = _role(profile.roleType);
        final slugText = _slugController.text.trim();
        final slug = slugText.isEmpty ? '' : publicProfileSlug(slugText);
        return RoleFixedHeaderPage(
          role: role,
          title: 'Portfolio Builder',
          subtitle:
              'Publish a safe public portfolio powered by publicProfiles.',
          showBackButton: true,
          onBack: () => context.canPop() ? context.pop() : context.go('/'),
          scrollable: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BuilderPanel(
                  profile: profile,
                  slugController: _slugController,
                  headlineController: _headlineController,
                  bioController: _bioController,
                  publish: _publish,
                  loading: actionState.isLoading,
                  publicLink: slug.isEmpty
                      ? null
                      : portfolioSettings.publicLinkFor(slug),
                  portfolioEnabled: portfolioSettings.isPortfolioEnabled,
                  onSlugChanged: (_) => setState(() {}),
                  onPublishChanged: (value) => setState(() => _publish = value),
                  onSave: () => _save(context, ref, profile),
                  onCopy: (link) => _copyLink(context, link),
                ),
                const SizedBox(height: 18),
                _Preview(profile: _currentProfile(profile)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _seed(PublicProfileModel profile) {
    if (_seeded) return;
    _seeded = true;
    _slugController.text = profile.slug;
    _headlineController.text = profile.headline;
    _bioController.text = profile.bio;
    _publish = profile.publicVisible;
  }

  PublicProfileModel _currentProfile(PublicProfileModel profile) {
    return PublicProfileModel(
      slug: publicProfileSlug(_slugController.text),
      userId: profile.userId,
      roleType: profile.roleType,
      displayName: profile.displayName,
      headline: _headlineController.text.trim(),
      bio: _bioController.text.trim(),
      avatarUrl: profile.avatarUrl,
      location: profile.location,
      skills: profile.skills,
      verifiedSkills: profile.verifiedSkills,
      projects: profile.projects,
      services: profile.services,
      coursesCreated: profile.coursesCreated,
      certificates: profile.certificates,
      reviews: profile.reviews,
      socialLinks: profile.socialLinks,
      contactMode: profile.contactMode,
      hireButtonEnabled: profile.hireButtonEnabled,
      publicVisible: _publish,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    PublicProfileModel profile,
  ) async {
    if (_slugController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a portfolio slug first.')),
      );
      return;
    }
    final success = await ref
        .read(publicProfileActionProvider.notifier)
        .saveProfile(_currentProfile(profile));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (_publish ? 'Portfolio published.' : 'Portfolio saved private.')
              : 'Unable to save portfolio.',
        ),
      ),
    );
  }

  Future<void> _copyLink(BuildContext context, String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Public portfolio link copied.')),
    );
  }
}

class _BuilderPanel extends StatelessWidget {
  const _BuilderPanel({
    required this.profile,
    required this.slugController,
    required this.headlineController,
    required this.bioController,
    required this.publish,
    required this.loading,
    required this.publicLink,
    required this.portfolioEnabled,
    required this.onSlugChanged,
    required this.onPublishChanged,
    required this.onSave,
    required this.onCopy,
  });

  final PublicProfileModel profile;
  final TextEditingController slugController;
  final TextEditingController headlineController;
  final TextEditingController bioController;
  final bool publish;
  final bool loading;
  final String? publicLink;
  final bool portfolioEnabled;
  final ValueChanged<String> onSlugChanged;
  final ValueChanged<bool> onPublishChanged;
  final VoidCallback onSave;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${profile.roleType.toUpperCase()} Public Profile',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: slugController,
            onChanged: onSlugChanged,
            decoration: const InputDecoration(
              labelText: 'Public slug',
              prefixText: '/p/',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: headlineController,
            decoration: const InputDecoration(labelText: 'Headline'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bioController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Bio'),
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: publish,
            onChanged: loading ? null : onPublishChanged,
            title: const Text('Public visible'),
            subtitle: const Text(
              'Only denormalized public-safe fields are published.',
            ),
          ),
          if (!portfolioEnabled) ...[
            const SizedBox(height: 8),
            Text(
              'Portfolio links are currently disabled by admin.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else if (publicLink == null) ...[
            const SizedBox(height: 8),
            Text(
              'Enter a portfolio slug first.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            SelectableText(
              publicLink!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: loading ? null : onSave,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save Portfolio'),
              ),
              OutlinedButton.icon(
                onPressed: !portfolioEnabled || publicLink == null
                    ? null
                    : () => onCopy(publicLink!),
                icon: const Icon(Icons.link_rounded),
                label: const Text('Copy Public Link'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.profile});

  final PublicProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final sections = <String, List<String>>{
      'Skills': profile.skills,
      'Verified Skills': profile.verifiedSkills,
      'Projects': profile.projects,
      'Services': profile.services,
      'Courses Created': profile.coursesCreated,
      'Certificates': profile.certificates,
      'Social Links': profile.socialLinks,
    };
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: profile.avatarUrl.isEmpty
                    ? null
                    : NetworkImage(profile.avatarUrl),
                child: profile.avatarUrl.isEmpty
                    ? const Icon(Icons.person_rounded)
                    : null,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 220, maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(profile.headline),
                  ],
                ),
              ),
              if (profile.publicVisible)
                const Chip(label: Text('Published'))
              else
                const Chip(label: Text('Private')),
            ],
          ),
          const SizedBox(height: 16),
          Text(profile.bio.isEmpty ? 'No bio added yet.' : profile.bio),
          const SizedBox(height: 18),
          for (final entry in sections.entries)
            if (entry.value.isNotEmpty) ...[
              Text(
                entry.key,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in entry.value.take(12))
                    Chip(label: Text(item)),
                ],
              ),
              const SizedBox(height: 14),
            ],
          if (profile.hireButtonEnabled)
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.handshake_rounded),
              label: const Text('Hire / Contact CTA Preview'),
            ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context) {
  final theme = Theme.of(context);
  return BoxDecoration(
    color: theme.colorScheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
    ),
  );
}

UserRole _role(String roleType) {
  return switch (roleType.trim().toLowerCase()) {
    'teacher' => UserRole.teacher,
    'freelancer' => UserRole.freelancer,
    'company' => UserRole.company,
    _ => UserRole.student,
  };
}
