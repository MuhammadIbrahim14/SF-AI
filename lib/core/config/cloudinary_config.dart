abstract final class CloudinaryConfig {
  static const String cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'dkq3uauew',
  );
  static const String uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'skillforge_ai',
  );
  static const String uploadFolder = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_FOLDER',
    defaultValue: 'skillforge/profile_images',
  );
  static const String deliveryFolder = String.fromEnvironment(
    'CLOUDINARY_DELIVERY_FOLDER',
    defaultValue: 'skillforge/deliveries',
  );

  static bool get isConfigured =>
      cloudName.trim().isNotEmpty && uploadPreset.trim().isNotEmpty;
}
