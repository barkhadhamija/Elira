import { useMemo, useRef, useState } from "react";
import styles from "./PINInput.module.css";

export default function PINInput({ onComplete, label }) {
  const [value, setValue] = useState("");
  const inputRef = useRef(null);

  const digits = useMemo(() => {
    return value.split("").slice(0, 4);
  }, [value]);

  function focus() {
    if (inputRef.current) inputRef.current.focus();
  }

  function commitIfComplete(next) {
    if (next.length !== 4) return;
    if (typeof onComplete === "function") onComplete(next);
  }

  function handleChange(e) {
    const raw = String(e.target.value || "");
    const onlyDigits = raw.replace(/\D/g, "").slice(0, 4);
    setValue(onlyDigits);
    commitIfComplete(onlyDigits);
  }

  return (
    <div className={styles.wrap}>
      <input
        ref={inputRef}
        className={styles.hiddenInput}
        type="tel"
        inputMode="numeric"
        aria-label={label || "PIN input"}
        autoComplete="one-time-code"
        value={value}
        onChange={handleChange}
      />

      <div className={styles.dotsRow} onClick={focus} role="group" aria-label={label || "Enter PIN"}>
        {Array.from({ length: 4 }, (_, idx) => {
          const filled = idx < digits.length;
          return (
            <div
              // eslint-disable-next-line react/no-array-index-key
              key={idx}
              className={`${styles.dot} ${filled ? styles.dotFilled : ""}`}
              aria-hidden="true"
            />
          );
        })}
      </div>
    </div>
  );
}
