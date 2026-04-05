import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/testimony_model.dart';

class AppState {
  final bool isLoggedIn;
  final bool isPinVerified;
  final bool gpsConsent;
  final List<String> contacts;
  final List<TestimonyModel> testimonies;

  const AppState({
    this.isLoggedIn = false,
    this.isPinVerified = false,
    this.gpsConsent = false,
    this.contacts = const [],
    this.testimonies = const [],
  });

  AppState copyWith({
    bool? isLoggedIn,
    bool? isPinVerified,
    bool? gpsConsent,
    List<String>? contacts,
    List<TestimonyModel>? testimonies,
  }) {
    return AppState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isPinVerified: isPinVerified ?? this.isPinVerified,
      gpsConsent: gpsConsent ?? this.gpsConsent,
      contacts: contacts ?? this.contacts,
      testimonies: testimonies ?? this.testimonies,
    );
  }
}

class AppNotifier extends StateNotifier<AppState> {
  AppNotifier() : super(const AppState());

  void setLoggedIn(bool value) {
    state = state.copyWith(isLoggedIn: value);
  }

  void setPinVerified(bool value) {
    state = state.copyWith(isPinVerified: value);
  }

  void setGpsConsent(bool value) {
    state = state.copyWith(gpsConsent: value);
  }

  void setContacts(List<String> contacts) {
    state = state.copyWith(contacts: List<String>.from(contacts));
  }

  void addTestimony(TestimonyModel testimony) {
    state = state.copyWith(
      testimonies: [testimony, ...state.testimonies],
    );
  }

  void setTestimonies(List<TestimonyModel> testimonies) {
    state = state.copyWith(testimonies: List<TestimonyModel>.from(testimonies));
  }

  void upsertTestimony(TestimonyModel testimony) {
    final existingIndex = state.testimonies
        .indexWhere((t) => t.evidenceId == testimony.evidenceId);

    if (existingIndex == -1) {
      addTestimony(testimony);
      return;
    }

    final updated = List<TestimonyModel>.from(state.testimonies);
    updated[existingIndex] = testimony;
    state = state.copyWith(testimonies: updated);
  }
}

final appProvider = StateNotifierProvider<AppNotifier, AppState>(
  (ref) => AppNotifier(),
);
