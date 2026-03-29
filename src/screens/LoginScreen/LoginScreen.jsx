import { useEffect, useMemo, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import useAppStore from "../../store/useAppStore";
import { isOnboardingComplete, jssaveSession } from "../../utils/session";
import styles from "./LoginScreen.module.css";

function sanitizePhone(value) {
  return String(value || "").replace(/[^\d+]/g, "");
}

export default function LoginScreen() {
  const navigate = useNavigate();
  const setLoggedIn = useAppStore((s) => s.setLoggedIn);

  const [step, setStep] = useState(1);
  const [phone, setPhone] = useState("");

  const digitsInit = useMemo(() => Array.from({ length: 6 }, () => ""), []);
  const [digits, setDigits] = useState(digitsInit);

  const inputRefs = useRef([]);

  useEffect(() => {
    if (step !== 2) return;
    const first = inputRefs.current[0];
    if (first) first.focus();
  }, [step]);

  function handleContinue() {
    const normalized = sanitizePhone(phone);
    if (!normalized) return;
    setPhone(normalized);
    setStep(2);
  }

  function completeIfReady(nextDigits) {
    const ready = nextDigits.every((d) => d !== "");
    if (!ready) return false;

    jssaveSession();
    setLoggedIn(true);
    if (isOnboardingComplete()) {
      navigate("/home", { replace: true });
    } else {
      navigate("/onboarding", { replace: true });
    }
    return true;
  }

  function onDigitChange(idx, value) {
    const onlyDigit = String(value || "").replace(/\D/g, "").slice(0, 1);
    const next = [...digits];
    next[idx] = onlyDigit;
    setDigits(next);

    if (onlyDigit) {
      const nextInput = inputRefs.current[idx + 1];
      if (nextInput) nextInput.focus();
    }

    completeIfReady(next);
  }

  function onDigitKeyDown(idx, e) {
    if (e.key === "Backspace") {
      const next = [...digits];
      if (next[idx]) {
        next[idx] = "";
        setDigits(next);
        return;
      }
      const prevInput = inputRefs.current[idx - 1];
      if (prevInput) {
        prevInput.focus();
      }
    }
  }

  return (
    <div className={styles.screen}>
      <div className={styles.content}>
        {step === 1 ? (
          <>
            <div className={styles.wordmark}>ELIRA</div>
            <div className={styles.tagline}>Your safety, your voice</div>

            <div className={styles.field}>
              <label className={styles.label} htmlFor="phone">
                Phone number
              </label>
              <input
                id="phone"
                className={styles.phoneInput}
                type="tel"
                inputMode="tel"
                autoComplete="tel"
                value={phone}
                onChange={(e) => setPhone(sanitizePhone(e.target.value))}
                placeholder="+1 555 123 4567"
              />
            </div>

            <button
              type="button"
              className={styles.primaryButton}
              onClick={handleContinue}
              disabled={!sanitizePhone(phone)}
            >
              Continue
            </button>
          </>
        ) : (
          <>
            <div className={styles.stepTitle}>
              Enter the 6-digit code sent to {phone || "your phone"}
            </div>

            <div className={styles.digitRow} aria-label="6-digit code input">
              {digits.map((d, idx) => (
                <input
                  // eslint-disable-next-line react/no-array-index-key
                  key={idx}
                  ref={(el) => {
                    inputRefs.current[idx] = el;
                  }}
                  className={styles.digitInput}
                  type="tel"
                  inputMode="numeric"
                  pattern="\d*"
                  maxLength={1}
                  value={d}
                  onChange={(e) => onDigitChange(idx, e.target.value)}
                  onKeyDown={(e) => onDigitKeyDown(idx, e)}
                  aria-label={`Digit ${idx + 1}`}
                />
              ))}
            </div>

            <div className={styles.hint}>Any 6 digits = success</div>
          </>
        )}
      </div>
    </div>
  );
}
