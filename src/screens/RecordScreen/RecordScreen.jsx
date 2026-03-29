import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import styles from "./RecordScreen.module.css";

function BackArrow() {
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
        d="M15 18L9 12L15 6"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function formatLiveTimestamp(d) {
  const date = new Intl.DateTimeFormat("en-GB", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  }).format(d);
  const time = new Intl.DateTimeFormat("en-GB", {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  }).format(d);
  return `${date} · ${time}`;
}

export default function RecordScreen() {
  const navigate = useNavigate();
  const [now, setNow] = useState(() => new Date());

  useEffect(() => {
    const id = window.setInterval(() => {
      setNow(new Date());
    }, 1000);
    return () => window.clearInterval(id);
  }, []);

  const liveTimestamp = useMemo(() => formatLiveTimestamp(now), [now]);

  return (
    <div className={styles.screen}>
      <div className={styles.topBar}>
        <button
          type="button"
          className={styles.backButton}
          onClick={() => navigate("/home")}
          aria-label="Back to home"
        >
          <BackArrow />
        </button>
      </div>

      <div className={styles.center}>
        <div className={styles.placeholder} aria-label="Camera placeholder (9:16)">
          <div className={styles.liveTimestamp}>{liveTimestamp}</div>
        </div>

        <div className={styles.titleField}>
          <input
            className={styles.titleInput}
            type="text"
            placeholder="Give this testimony a title..."
            aria-label="Testimony title"
          />
        </div>
      </div>

      <button type="button" className={styles.recordButton} aria-label="Record (not implemented)">
        Record
      </button>
    </div>
  );
}
