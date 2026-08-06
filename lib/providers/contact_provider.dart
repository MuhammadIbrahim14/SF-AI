import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/contact_repository.dart';
import '../models/contact_message_model.dart';

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  return ContactRepository();
});

class ContactFilters {
  final String status;
  final String category;

  const ContactFilters({this.status = 'All', this.category = 'All'});

  ContactFilters copyWith({String? status, String? category}) {
    return ContactFilters(
      status: status ?? this.status,
      category: category ?? this.category,
    );
  }
}

class ContactFiltersNotifier extends Notifier<ContactFilters> {
  @override
  ContactFilters build() => const ContactFilters();

  void updateState(ContactFilters newFilters) {
    state = newFilters;
  }
}

final contactFiltersProvider =
    NotifierProvider<ContactFiltersNotifier, ContactFilters>(() {
      return ContactFiltersNotifier();
    });

final contactMessagesProvider =
    StreamProvider.autoDispose<List<ContactMessage>>((ref) {
      final repository = ref.watch(contactRepositoryProvider);
      final filters = ref.watch(contactFiltersProvider);

      return repository.streamMessages(
        statusFilter: filters.status,
        categoryFilter: filters.category,
      );
    });

final unreadMessagesCountProvider = StreamProvider.autoDispose<int>((ref) {
  final repository = ref.watch(contactRepositoryProvider);
  return repository
      .streamMessages(statusFilter: 'new')
      .map((msgs) => msgs.length);
});

final userContactMessagesProvider = StreamProvider.autoDispose
    .family<List<ContactMessage>, String>((ref, userId) {
      final repository = ref.watch(contactRepositoryProvider);
      return repository.streamUserMessages(userId);
    });
