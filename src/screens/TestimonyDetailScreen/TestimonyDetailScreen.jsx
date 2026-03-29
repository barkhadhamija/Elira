import { useMemo } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { testimonies } from "../../data/mockData";
import styles from "./TestimonyDetailScreen.module.css";

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

function PlayIcon() {
  return (
    <svg
      width="36"
      height="36"
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
    >
      <path
        d="M10 8.5V15.5L16 12L10 8.5Z"
        fill="currentColor"
      />
      <path
        d="M12 22C17.5228 22 22 17.5228 22 12C22 6.47715 17.5228 2 12 2C6.47715 2 2 6.47715 2 12C2 17.5228 6.47715 22 12 22Z"
        stroke="currentColor"
        strokeWidth="2"
      />
    </svg>
  );
}

function formatDate(iso) {
  const dt = new Date(iso);
  if (Number.isNaN(dt.getTime())) return "";
  return new Intl.DateTimeFormat("en-GB", {
    day: "2-digit",
    month: "long",
    year: "numeric",
  }).format(dt);
}

function truncateMiddle(value) {
  const v = String(value || "");
  if (v.length <= 16) return v;
  return `${v.slice(0, 8)}...${v.slice(-8)}`;
}

function getStatusStyle(status) {
  if (status === "Uploading") return styles.badgeUploading;
  if (status === "Certified") return styles.badgeCertified;
  return styles.badgeRecorded;
}

export default function TestimonyDetailScreen() {
  const navigate = useNavigate();
  const { id } = useParams();

  const testimony = useMemo(() => {
    return testimonies.find((t) => t.id === id) || null;
  }, [id]);

  if (!testimony) {
    return (
      <div className={styles.screen}>
        <div className={styles.topBar}>
          <button type="button" className={styles.backButton} onClick={() => navigate("/home")} aria-label="Back to home">
            <BackArrow />
          </button>
        </div>
        <div className={styles.notFound}>Not found</div>
      </div>
    );
  }

  const gpsText = testimony.gps
    ? `${testimony.gps.lat}, ${testimony.gps.lng}`
    : "No location recorded";

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

      <div className={styles.content}>
        <div className={styles.title}>{testimony.title}</div>

        <div className={styles.metaRow}>
          <div className={styles.metaStrong}>{formatDate(testimony.date)}</div>
          <div className={styles.metaText}>Duration: {testimony.duration}</div>
        </div>

        <div className={styles.gpsRow}>
          <div className={styles.gpsLabel}>GPS</div>
          <div className={styles.gpsText}>{gpsText}</div>
        </div>

        <div className={`${styles.badgeBase} ${getStatusStyle(testimony.status)}`}>{testimony.status}</div>

        <div className={styles.videoPlaceholder} aria-label="Video placeholder">
          <div className={styles.playIconWrap}>
            <PlayIcon />
          </div>
        </div>

        <div className={styles.sectionHeadingRow}>
          <div className={styles.sectionHeading}>AI Generated Summary</div>
          <div className={styles.aiBadge}>AI</div>
        </div>

        <div className={styles.summaryText}>{testimony.aiSummary}</div>

        <div className={styles.blockHeading}>Blockchain Record</div>

        <div className={styles.row}>
          <div className={styles.rowLabel}>Arweave</div>
          <div className={styles.rowValue}>{truncateMiddle(testimony.arweaveTxId)}</div>
        </div>

        <div className={styles.row}>
          <div className={styles.rowLabel}>Polygon</div>
          <div className={styles.rowValue}>{truncateMiddle(testimony.polygonHash)}</div>
        </div>

        <button
          type="button"
          className={styles.downloadButton}
          onClick={() => alert("Certificate download coming soon")}
        >
          Download Certificate
        </button>

        <div className={styles.bottomPad} aria-hidden="true" />
      </div>
    </div>
  );
}
