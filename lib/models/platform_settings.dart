class PlatformSettings {
  const PlatformSettings({
    this.maintenanceMode = false,
    this.registrationEnabled = true,
    this.companySignupEnabled = true,
    this.teacherSignupEnabled = true,
    this.appAnnouncement = '',
    this.updateTitle = '',
    this.updateMessage = '',
    this.latestVersion = '',
    this.minimumSupportedVersion = '',
    this.requireTeacherVerification = true,
    this.requireCompanyVerification = true,
    this.sieGloballyEnabled = true,
  });

  final bool maintenanceMode;
  final bool registrationEnabled;
  final bool companySignupEnabled;
  final bool teacherSignupEnabled;
  final String appAnnouncement;
  final String updateTitle;
  final String updateMessage;
  final String latestVersion;
  final String minimumSupportedVersion;
  final bool requireTeacherVerification;
  final bool requireCompanyVerification;

  /// Master switch for Spatial Interaction Engine across all roles.
  ///
  /// When false, SIE host bootstrap is blocked and PRF kill switch is armed.
  final bool sieGloballyEnabled;

  bool get allowRegistrations => registrationEnabled;

  factory PlatformSettings.fromJson(Map<String, dynamic> data) {
    return PlatformSettings(
      maintenanceMode: data['maintenanceMode'] == true,
      registrationEnabled:
          (data['registrationEnabled'] ?? data['allowRegistrations']) != false,
      companySignupEnabled: data['companySignupEnabled'] != false,
      teacherSignupEnabled: data['teacherSignupEnabled'] != false,
      appAnnouncement: data['appAnnouncement']?.toString() ?? '',
      updateTitle: data['updateTitle']?.toString() ?? '',
      updateMessage: data['updateMessage']?.toString() ?? '',
      latestVersion: data['latestVersion']?.toString() ?? '',
      minimumSupportedVersion:
          data['minimumSupportedVersion']?.toString() ?? '',
      requireTeacherVerification: data['requireTeacherVerification'] != false,
      requireCompanyVerification: data['requireCompanyVerification'] != false,
      // Default ON when field missing (backward compatible).
      sieGloballyEnabled: data['sieGloballyEnabled'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maintenanceMode': maintenanceMode,
      'registrationEnabled': registrationEnabled,
      'allowRegistrations': registrationEnabled,
      'companySignupEnabled': companySignupEnabled,
      'teacherSignupEnabled': teacherSignupEnabled,
      'appAnnouncement': appAnnouncement,
      'updateTitle': updateTitle,
      'updateMessage': updateMessage,
      'latestVersion': latestVersion,
      'minimumSupportedVersion': minimumSupportedVersion,
      'requireTeacherVerification': requireTeacherVerification,
      'requireCompanyVerification': requireCompanyVerification,
      'sieGloballyEnabled': sieGloballyEnabled,
    };
  }

  PlatformSettings copyWith({
    bool? maintenanceMode,
    bool? registrationEnabled,
    bool? companySignupEnabled,
    bool? teacherSignupEnabled,
    String? appAnnouncement,
    String? updateTitle,
    String? updateMessage,
    String? latestVersion,
    String? minimumSupportedVersion,
    bool? requireTeacherVerification,
    bool? requireCompanyVerification,
    bool? sieGloballyEnabled,
  }) {
    return PlatformSettings(
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      registrationEnabled: registrationEnabled ?? this.registrationEnabled,
      companySignupEnabled: companySignupEnabled ?? this.companySignupEnabled,
      teacherSignupEnabled: teacherSignupEnabled ?? this.teacherSignupEnabled,
      appAnnouncement: appAnnouncement ?? this.appAnnouncement,
      updateTitle: updateTitle ?? this.updateTitle,
      updateMessage: updateMessage ?? this.updateMessage,
      latestVersion: latestVersion ?? this.latestVersion,
      minimumSupportedVersion:
          minimumSupportedVersion ?? this.minimumSupportedVersion,
      requireTeacherVerification:
          requireTeacherVerification ?? this.requireTeacherVerification,
      requireCompanyVerification:
          requireCompanyVerification ?? this.requireCompanyVerification,
      sieGloballyEnabled: sieGloballyEnabled ?? this.sieGloballyEnabled,
    );
  }
}
