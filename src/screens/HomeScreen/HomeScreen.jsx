import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import useAppStore from "../../store/useAppStore";
import { getPin } from "../../utils/session";
import { testimonies } from "../../data/mockData";
import TestimonyCard from "../../components/TestimonyCard/TestimonyCard";
import PINInput from "../../components/PINInput/PINInput";
import styles from "./HomeScreen.module.css";

function SettingsIcon() {
  return (
    <svg
      width="22"
      height="22"
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
    >
      <path
        d="M12 15.5C13.933 15.5 15.5 13.933 15.5 12C15.5 10.067 13.933 8.5 12 8.5C10.067 8.5 8.5 10.067 8.5 12C8.5 13.933 10.067 15.5 12 15.5Z"
        stroke="currentColor"
        strokeWidth="2"
      />
      <path
        d="M19.4 15C19.8 14.3 20 13.5 20 12.7V11.3C20 10.5 19.8 9.7 19.4 9L21 7.4L18.6 5L17 6.6C16.3 6.2 15.5 6 14.7 6H13.3C12.5 6 11.7 6.2 11 6.6L9.4 5L7 7.4L8.6 9C8.2 9.7 8 10.5 8 11.3V12.7C8 13.5 8.2 14.3 8.6 15L7 16.6L9.4 19L11 17.4C11.7 17.8 12.5 18 13.3 18H14.7C15.5 18 16.3 17.8 17 17.4L18.6 19L21 16.6L19.4 15Z"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinejoin="round"
      />
    </svg>
  );
}

export default function HomeScreen() {
  const navigate = useNavigate();
  const isPINVerified = useAppStore((s) => s.isPINVerified);
  const setPINVerified = useAppStore((s) => s.setPINVerified);

  const [pinError, setPinError] = useState("");

  const title = useMemo(() => "Your testimonies", []);

  useEffect(() => {
    setPinError("");
  }, [isPINVerified]);

  function handlePinComplete(pin) {
    const savedPin = getPin();
    if (!savedPin || pin !== savedPin) {
      setPINError("Incorrect PIN. Please try again.");
      return;
    }
    setPINVerified(true);
    setPinError("");
  }

  return (
    <div className={styles.screen}>
      {isPINVerified ? (
        <>
          <div className={styles.header}>
            <div className={styles.headerLeft}>ELIRA</div>
            <button type="button" className={styles.settingsButton} aria-label="Settings (not implemented)">
              <SettingsIcon />
            </button>
          </div>

          <div className={styles.subheading}>{title}</div>

          <div className={styles.list}>
            {testimonies.map((t) => (
              <TestimonyCard key={t.id} testimony={t} />
            ))}
          </div>

          <div className={styles.bottomPadding} aria-hidden="true" />

          <button
            type="button"
            className={styles.recordButton}
            onClick={() => navigate("/record")}
            aria-label="Record a new testimony"
          >
            Record
          </button>
        </>
      ) : (
        <div className={styles.pinWrap}>
          <div className={styles.pinTitle}>Verify your PIN</div>
          <div className={styles.pinHelp}>
            Enter your 4-digit PIN to access your testimonies.
          </div>
          <PINInput label="PIN" onComplete={handlePinComplete} />
          {pinError ? <div className={styles.pinError}>{pinError}</div> : null}
        </div>
      )}
    </div>
  );
}
