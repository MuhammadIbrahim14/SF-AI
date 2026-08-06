import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/notifications/notification_events.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/contact_message_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/contact_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';

class ContactScreen extends ConsumerStatefulWidget {
  const ContactScreen({super.key});

  @override
  ConsumerState<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends ConsumerState<ContactScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _subjectController;
  late TextEditingController _messageController;

  String _selectedCategory = 'General';
  bool _isLoading = false;

  final List<String> _categories = [
    'General',
    'Support',
    'Course Issue',
    'Job/Hiring',
    'Freelancer Services',
    'Account Deletion',
    'Legal/Privacy',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _subjectController = TextEditingController();
    _messageController = TextEditingController();

    // Delay the provider read to allow the widget tree to mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider).value;
      if (user != null) {
        _nameController.text = user.fullName;
        _emailController.text = user.email;
        setState(() {}); // trigger rebuild to show prefilled data
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final router = GoRouter.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final user = ref.read(currentUserProvider).value;
      final repository = ref.read(contactRepositoryProvider);
      final message = ContactMessage(
        messageId: FirebaseFirestore.instance
            .collection('contactMessages')
            .doc()
            .id,
        userId: user?.uid,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        subject: _subjectController.text.trim(),
        category: _selectedCategory,
        message: _messageController.text.trim(),
        status: 'new',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.sendMessage(message);

      // Admin in-app fan-out requires a signed-in actor (client write to
      // users/{adminId}/notifications). Guests still create the ticket;
      // staff see it in Support Inbox and reply via email on the ticket.
      if (user != null) {
        try {
          final adminIds = await ref
              .read(adminRepositoryProvider)
              .listAdminRecipientIds();
          if (adminIds.isNotEmpty) {
            final subject = message.subject.trim().isEmpty
                ? 'Support ticket'
                : message.subject.trim();
            await ref.read(notificationServiceProvider).notifyMany(
              recipientIds: adminIds,
              title: 'New support ticket',
              body: '$subject — ${message.category}',
              category: NotificationCategories.support,
              event: NotificationEvents.supportTicketCreated,
              actorId: user.uid,
              actorName: message.name.trim().isEmpty ? null : message.name,
              actorRole: user.primaryRole,
              relatedPath: 'contactMessages/${message.messageId}',
              routeName: RouteNames.adminInbox,
              priority: message.priority == 'high' ? 'high' : 'normal',
              meta: {
                'messageId': message.messageId,
                'category': message.category,
              },
            );
          }
        } catch (_) {
          // Primary action already succeeded.
        }
      }

      if (mounted) {
        if (user != null) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: const Text('Your message has been sent successfully.'),
              backgroundColor: AppColors.success,
              action: SnackBarAction(
                label: 'View My Requests',
                textColor: Colors.white,
                onPressed: () {
                  router.pushNamed(RouteNames.mySupportRequests);
                },
              ),
            ),
          );
          if (router.canPop()) {
            router.pop();
          } else {
            router.go('/');
          }
        } else {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Ticket submitted. Our team will reply by email to the '
                'address you provided. Admins can also see it in Support Inbox.',
              ),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 5),
            ),
          );
          if (router.canPop()) {
            router.pop();
          } else {
            router.go('/');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    final user = ref.watch(currentUserProvider).value;
    final role = UserRole.fromString(user?.primaryRole) ?? UserRole.student;

    // Use RoleFixedHeaderPage if logged in, otherwise regular Scaffold
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contact Us'), centerTitle: true),
        body: _buildBody(context, colorScheme, isMobile, isGuest: true),
      );
    }

    return RoleFixedHeaderPage(
      role: role,
      title: 'Contact Support',
      subtitle: 'Get help, report an issue, or ask a question',
      showBackButton: true,
      scrollable: false,
      child: _buildBody(context, colorScheme, isMobile, isGuest: false),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ColorScheme colorScheme,
    bool isMobile, {
    required bool isGuest,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Get in Touch',
                  style: AppTypography.displaySmall.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isGuest
                      ? 'Fill out the form below. We will reply by email to the '
                          'address you provide. Our team also sees your ticket in '
                          'Support Inbox. Sign in to track requests in-app.'
                      : 'Have a question or need assistance? Fill out the form '
                          'below and our support team will respond as soon as possible.',
                  style: AppTypography.bodyLarge.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Name & Email
                if (isMobile) ...[
                  CustomTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    hint: 'John Doe',
                    prefixIcon: Icons.person_outline,
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Please enter your name'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    hint: 'john@example.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your email';
                      }

                      if (!val.contains('@')) {
                        return 'Please enter a valid email';
                      }

                      return null;
                    },
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CustomTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          hint: 'John Doe',
                          prefixIcon: Icons.person_outline,
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Please enter your name'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: CustomTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          hint: 'john@example.com',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.email_outlined,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter your email';
                            }

                            if (!val.contains('@')) {
                              return 'Please enter a valid email';
                            }

                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),

                // Category Dropdown
                Text(
                  'Category',
                  style: AppTypography.labelLarge.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  dropdownColor: colorScheme.surface,
                  items: _categories.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
                const SizedBox(height: 20),

                // Subject
                CustomTextField(
                  controller: _subjectController,
                  label: 'Subject',
                  hint: 'Briefly describe your issue',
                  prefixIcon: Icons.subject,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Please enter a subject'
                      : null,
                ),
                const SizedBox(height: 20),

                // Message
                CustomTextField(
                  controller: _messageController,
                  label: 'Message',
                  hint: 'How can we help you?',
                  maxLines: 6,
                  keyboardType: TextInputType.multiline,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Please enter your message'
                      : null,
                ),
                const SizedBox(height: 40),

                // Submit
                FilledButton.icon(
                  onPressed: _isLoading ? null : _submitForm,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Send Message'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: AppTypography.labelLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
