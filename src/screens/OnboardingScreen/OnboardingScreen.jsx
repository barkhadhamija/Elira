import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import PINInput from "../../components/PINInput/PINInput";
import useAppStore from "../../store/useAppStore";
import {
  getContacts,
  saveContacts,
  savePIN,
  setOnboardingComplete,
} from "../../utils/session";
import styles from "./OnboardingScreen.module.css";

function clampContacts(arr) {
  const cleaned = Array.isArray(arr) ? arr : [];
  const trimmed = cleaned
    .map((c) => ({
      name: String(c?.name || "").trim(),
      phone: String(c?.phone || "").trim(),
    }))
    .filter((c) => c.name && c.phone);
  return trimmed.slice(0, 3);
}

function StepIndicator({ step }) {
  const steps = [1, 2, 3, 4];
  return (
    <div className={styles.stepIndicator} aria-label={`Step ${step} of 4`}>
      {steps.map((n) => (
        <div
          // eslint-disable-next-line react/no-array-index-key
          key={n}
          className={`${styles.stepDot} ${n === step ? styles.stepDotActive : ""}`}
          aria-hidden="true"
        />
      ))}
    </div>
  );
}

export default function OnboardingScreen() {
  const navigate = useNavigate();

  const gpsConsent = useAppStore((s) => s.gpsConsent);
  const setGpsConsent = useAppStore((s) => s.setGpsConsent);
  const setPINVerified = useAppStore((s) => s.setPINVerified);

  const [step, setStep] = useState(1);
  const [dataConsent, setDataConsent] = useState(false);

  const [contacts, setContactsState] = useState(() => {
    // If onboarding restarts, show any previously saved contacts for convenience.
    const existing = getContacts();
    return existing.length ? existing.slice(0, 3) : [{ name: "", phone: "" }];
  });

  const [pin, setPin] = useState("");
  const [pinConfirm, setPinConfirmState] = useState("");
  const [pinError, setPinError] = useState("");

  const title = useMemo(() => {
    if (step === 1) return "GPS Consent";
    if (step === 2) return "Data Consent";
    if (step === 3) return "SOS Contacts";
    return "Set Your PIN";
  }, [step]);

  function setContacts(next) {
    setContactsState(Array.isArray(next) ? next : []);
  }

  function goNext() {
    if (step === 1) {
      setStep(2);
      return;
    }
    if (step === 2) {
      if (!dataConsent) return;
      setStep(3);
      return;
    }
    if (step === 3) {
      const cleaned = clampContacts(contacts);
      saveContacts(cleaned);
      setStep(4);
      return;
    }
  }

  function handleSkipContacts() {
    saveContacts([]);
    setStep(4);
  }

  function handlePinComplete(value, which) {
    setPinError("");
    if (which === "pin") setPin(value);
    if (which === "pinConfirm") setPinConfirmState(value);

    if (which === "pinConfirm") {
      const match = pin === value;
      if (!match) {
        setPinError("PINs do not match. Please try again.");
        setPin("");
        setPinConfirmState("");
        return;
      }
      if (!value || value.length !== 4) return;

      savePIN(value);
      setOnboardingComplete();
      setPINVerified(true);
      navigate("/home", { replace: true });
    }
  }

  return (
    <div className={styles.screen}>
      <div className={styles.container}>
        <StepIndicator step={step} />
        <div className={styles.title}>{title}</div>

        {step === 1 ? (
          <div className={styles.section}>
            <div className={styles.sectionText}>
              Turn on GPS to record where your testimony was captured. You can change your choice later.
            </div>

            <label className={styles.toggleRow}>
              <input
                type="checkbox"
                checked={gpsConsent}
                onChange={(e) => setGpsConsent(e.target.checked)}
                className={styles.toggleInput}
              />
              <span className={styles.toggleLabel}>
                I consent to GPS location access
              </span>
            </label>

            <button
              type="button"
              className={styles.primaryButton}
              onClick={goNext}
            >
              Continue
            </button>
          </div>
        ) : null}

        {step === 2 ? (
          <div className={styles.section}>
            <div className={styles.sectionText}>
              Allow ELIRA to store your consented information so your testimony can be safely organized.
            </div>

            <label className={styles.checkboxRow}>
              <input
                type="checkbox"
                checked={dataConsent}
                onChange={(e) => setDataConsent(e.target.checked)}
                className={styles.checkboxInput}
              />
              <span className={styles.checkboxLabel}>
                I agree to data processing for this app
              </span>
            </label>

            <button
              type="button"
              className={styles.primaryButton}
              onClick={goNext}
              disabled={!dataConsent}
            >
              Next
            </button>
          </div>
        ) : null}

        {step === 3 ? (
          <div className={styles.section}>
            <div className={styles.sectionText}>
              Add up to 3 trusted people to contact in an emergency. Skip if you prefer not to.
            </div>

            <div className={styles.contactsGrid}>
              {[0, 1, 2].map((idx) => {
                const current = contacts[idx] || { name: "", phone: "" };
                const isLast = idx === 2;
                return (
                  <div key={idx} className={styles.contactSlot}>
                    <div className={styles.slotLabel}>Contact {idx + 1}</div>
                    <input
                      className={styles.textInput}
                      value={current.name}
                      onChange={(e) => {
                        const next = [...contacts];
                        next[idx] = { ...current, name: e.target.value };
                        setContacts(next);
                      }}
                      placeholder="Name"
                      type="text"
                      inputMode="text"
                      aria-label={`Contact ${idx + 1} name`}
                    />
                    <input
                      className={styles.textInput}
                      value={current.phone}
                      onChange={(e) => {
                        const next = [...contacts];
                        next[idx] = { ...current, phone: e.target.value };
                        setContacts(next);
                      }}
                      placeholder="Phone"
                      type="tel"
                      inputMode="tel"
                      aria-label={`Contact ${idx + 1} phone`}
                    />
                  </div>
                );
              })}
            </div>

            <div className={styles.actionsRow}>
              <button
                type="button"
                className={styles.secondaryButton}
                onClick={handleSkipContacts}
              >
                Skip
              </button>
              <button
                type="button"
                className={styles.primaryButton}
                onClick={goNext}
              >
                Next
              </button>
            </div>
          </div>
        ) : null}

        {step === 4 ? (
          <div className={styles.section}>
            <div className={styles.sectionText}>
              Choose a 4-digit PIN. It will be required to protect access to your testimonies.
            </div>

            <div className={styles.pinBlock}>
              <div className={styles.pinLabel}>PIN</div>
              <PINInput
                label="PIN"
                onComplete={(value) => handlePinComplete(value, "pin")}
              />
            </div>

            <div className={styles.pinBlock}>
              <div className={styles.pinLabel}>Confirm PIN</div>
              <PINInput
                label="Confirm PIN"
                onComplete={(value) => handlePinComplete(value, "pinConfirm")}
              />
            </div>

            {pinError ? <div className={styles.errorText}>{pinError}</div> : null}

            <div className={styles.noteText}>
              If you forget your PIN, you may need to start onboarding again.
            </div>
          </div>
        ) : null}
      </div>
    </div>
  );
}
