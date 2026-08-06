import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pdf/certificate_design_config.dart';
import '../pdf/resume_design_config.dart';

class CertificateDesignConfigNotifier
    extends Notifier<CertificateDesignConfig> {
  @override
  CertificateDesignConfig build() => CertificateDesignConfig.standard;

  void updateConfig(CertificateDesignConfig config) {
    state = config;
  }
}

final certificateDesignConfigProvider =
    NotifierProvider<CertificateDesignConfigNotifier, CertificateDesignConfig>(
      CertificateDesignConfigNotifier.new,
    );

class ResumeDesignConfigNotifier extends Notifier<ResumeDesignConfig> {
  @override
  ResumeDesignConfig build() => ResumeDesignConfig.standard;

  void updateConfig(ResumeDesignConfig config) {
    state = config;
  }
}

final resumeDesignConfigProvider =
    NotifierProvider<ResumeDesignConfigNotifier, ResumeDesignConfig>(
      ResumeDesignConfigNotifier.new,
    );
