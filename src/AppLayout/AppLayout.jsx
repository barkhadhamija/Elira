import { Outlet } from "react-router-dom";
import SOSButton from "../components/SOSButton/SOSButton";
import styles from "./AppLayout.module.css";

export default function AppLayout() {
  return (
    <div className={styles.page}>
      <SOSButton />
      <div className={styles.container}>
        <Outlet />
      </div>
    </div>
  );
}
