import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/firebase_providers.dart';
import 'emailjs_config.dart';
import 'emailjs_mailer_service.dart';

final emailJsMailerServiceProvider = Provider<EmailJsMailerService>((ref) {
  return EmailJsMailerService(firestore: ref.watch(firestoreProvider));
});

final emailJsConfigProvider = StreamProvider<EmailJsConfig>((ref) {
  return ref.watch(emailJsMailerServiceProvider).watchConfig();
});
