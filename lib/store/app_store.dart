import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/testimony_model.dart';

class AppState {
  final bool isLoggedIn;
  final bool isPinVerified;
  final bool gpsConsent;
  final List<String> contacts;
  final List<TestimonyModel> testimonies;

  AppState({
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
  AppNotifier() : super(AppState());

  void setLoggedIn(bool value) =>
      state = state.copyWith(isLoggedIn: value);
  void setPinVerified(bool value) =>
      state = state.copyWith(isPinVerified: value);
  void setGpsConsent(bool value) =>
      state = state.copyWith(gpsConsent: value);
  void setContacts(List<String> contacts) =>
      state = state.copyWith(contacts: contacts);
  void addTestimony(TestimonyModel testimony) {
    state = state.copyWith(
      testimonies: [testimony, ...state.testimonies],
    );
  }
}

final appProvider = StateNotifierProvider<AppNotifier, AppState>(
  (ref) => AppNotifier(),
);
