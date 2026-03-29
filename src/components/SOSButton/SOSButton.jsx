import { useEffect, useMemo, useRef, useState } from "react";
import { getContacts, getSession } from "../../utils/session";
import styles from "./SOSButton.module.css";

export default function SOSButton() {
  const [isOpen, setIsOpen] = useState(false);
  const [secondsLeft, setSecondsLeft] = useState(5);
  const intervalRef = useRef(null);

  const sessionValid = useMemo(() => {
    // Snapshot session state on render/open; modal content shouldn't flicker mid-countdown.
    return Boolean(getSession());
  }, [isOpen]);

  const contacts = useMemo(() => {
    if (!sessionValid) return [];
    return getContacts();
  }, [sessionValid]);

  function resetAndClose() {
    setSecondsLeft(5);
    setIsOpen(false);
    if (intervalRef.current) {
      window.clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
  }

  useEffect(() => {
    if (!isOpen) return;

    setSecondsLeft(5);
    if (intervalRef.current) {
      window.clearInterval(intervalRef.current);
      intervalRef.current = null;
    }

    intervalRef.current = window.setInterval(() => {
      setSecondsLeft((prev) => {
        const next = prev - 1;
        if (next <= 0) {
          if (intervalRef.current) {
            window.clearInterval(intervalRef.current);
            intervalRef.current = null;
          }
          window.location.href = "tel:112";
          return 0;
        }
        return next;
      });
    }, 1000);

    return () => {
      if (intervalRef.current) {
        window.clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
    };
  }, [isOpen]);

  return (
    <>
      <button
        type="button"
        className={styles.sosButton}
        onClick={() => setIsOpen(true)}
        aria-label="Emergency SOS"
      >
        SOS
      </button>

      {isOpen ? (
        <div
          className={styles.overlay}
          role="dialog"
          aria-modal="true"
          aria-label="Emergency SOS modal"
        >
          <div className={styles.modal}>
            <div className={styles.heading}>Emergency SOS</div>

            <div className={styles.countdownRow}>
              <div className={styles.countdownValue}>
                {secondsLeft > 0 ? secondsLeft : 0}
              </div>
              <div className={styles.countdownText}>
                Calling 112
              </div>
            </div>

            {sessionValid ? (
              <div className={styles.section}>
                <div className={styles.sectionTitle}>SOS contacts</div>
                {contacts.length ? (
                  <div className={styles.contactsList}>
                    {contacts.slice(0, 3).map((c, idx) => (
                      <div key={`${c?.phone || idx}-${idx}`} className={styles.contactRow}>
                        <div className={styles.contactName}>{c?.name || "Contact"}</div>
                        <div className={styles.contactPhone}>{c?.phone || ""}</div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className={styles.muted}>No contacts saved.</div>
                )}
              </div>
            ) : null}

            <div className={styles.actions}>
              <button
                type="button"
                className={styles.cancelButton}
                onClick={resetAndClose}
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}
