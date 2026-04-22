import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:desktop_app/ui/onboarding/onboarding_models.dart';

class SavedOnboardingProgress {
  const SavedOnboardingProgress({
    required this.currentStep,
    required this.draft,
  });

  final int currentStep;
  final OnboardingDraft draft;
}

class OnboardingDraftStorage {
  static const _storage = FlutterSecureStorage(
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );

  static const _keyPrefix = 'onboarding_progress';

  Future<SavedOnboardingProgress?> load(String userId) async {
    final raw = await _storage.read(key: _keyFor(userId));
    if (raw == null || raw.isEmpty) return null;

    final json = jsonDecode(raw) as Map<String, dynamic>;
    return SavedOnboardingProgress(
      currentStep: json['currentStep'] as int? ?? 0,
      draft: OnboardingDraft.fromJson(
        json['draft'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  Future<void> save({
    required String userId,
    required int currentStep,
    required OnboardingDraft draft,
  }) {
    final payload = jsonEncode({
      'currentStep': currentStep,
      'draft': draft.toJson(),
    });

    return _storage.write(
      key: _keyFor(userId),
      value: payload,
    );
  }

  Future<void> clear(String userId) => _storage.delete(key: _keyFor(userId));

  String _keyFor(String userId) => '$_keyPrefix:$userId';
}
