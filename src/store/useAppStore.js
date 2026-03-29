import { create } from "zustand";

const useAppStore = create((set) => ({
  isLoggedIn: false,
  isPINVerified: false,
  contacts: [],
  gpsConsent: false,
  setLoggedIn: (value) => set({ isLoggedIn: Boolean(value) }),
  setPINVerified: (value) => set({ isPINVerified: Boolean(value) }),
  setContacts: (arr) => set({ contacts: Array.isArray(arr) ? arr : [] }),
  setGpsConsent: (value) => set({ gpsConsent: Boolean(value) }),
}));

export default useAppStore;
