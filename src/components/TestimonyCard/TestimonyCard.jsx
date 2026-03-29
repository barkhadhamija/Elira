import { useMemo } from "react";
import { useNavigate } from "react-router-dom";
import styles from "./TestimonyCard.module.css";

function formatDate(iso) {
  const dt = new Date(iso);
  if (Number.isNaN(dt.getTime())) return "";
  return new Intl.DateTimeFormat("en-GB", {
    day: "2-digit",
    month: "long",
    year: "numeric",
  }).format(dt);
}

function ChevronRight() {
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
        d="M9 18L15 12L9 6"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function getStatusStyle(status) {
  if (status === "Uploading") return styles.badgeUploading;
  if (status === "Certified") return styles.badgeCertified;
  return styles.badgeRecorded;
}

export default function TestimonyCard({ testimony }) {
  const navigate = useNavigate();

  const dateText = useMemo(() => formatDate(testimony?.date), [testimony?.date]);
  const statusClass = useMemo(
    () => getStatusStyle(testimony?.status),
    [testimony?.status]
  );

  return (
    <button
      type="button"
      className={styles.cardButton}
      onClick={() => navigate(`/testimony/${testimony.id}`)}
      aria-label={`Open testimony: ${testimony.title}`}
    >
      <div className={styles.left}>
        <div className={styles.title}>{testimony.title}</div>
        <div className={styles.metaLine}>{dateText}</div>
        <div className={styles.metaLine}>
          Duration: <span className={styles.mono}>{testimony.duration}</span>
        </div>
        <div className={`${styles.badgeBase} ${statusClass}`}>{testimony.status}</div>
      </div>

      <div className={styles.right}>
        <ChevronRight />
      </div>
    </button>
  );
}
