import { useEffect } from "react";
import { Navigate, Route, Routes, useLocation, useNavigate } from "react-router-dom";
import { isOnboardingComplete, getSession } from "./utils/session";
import AppLayout from "./AppLayout/AppLayout";
import LoginScreen from "./screens/LoginScreen/LoginScreen";
import OnboardingScreen from "./screens/OnboardingScreen/OnboardingScreen";
import HomeScreen from "./screens/HomeScreen/HomeScreen";
import RecordScreen from "./screens/RecordScreen/RecordScreen";
import TestimonyDetailScreen from "./screens/TestimonyDetailScreen/TestimonyDetailScreen";

export default function App() {
  const navigate = useNavigate();
  const location = useLocation();

  const initialPath = (() => {
    const session = getSession();
    const onboardingDone = isOnboardingComplete();
    if (!session) return "/login";
    if (onboardingDone) return "/home";
    return "/onboarding";
  })();

  useEffect(() => {
    if (!location?.pathname) return;
    if (location.pathname !== initialPath) {
      navigate(initialPath, { replace: true });
    }
  }, [initialPath, location?.pathname, navigate]);

  return (
    <Routes>
      <Route element={<AppLayout />}>
        <Route path="/login" element={<LoginScreen />} />
        <Route path="/onboarding" element={<OnboardingScreen />} />
        <Route path="/home" element={<HomeScreen />} />
        <Route path="/record" element={<RecordScreen />} />
        <Route path="/testimony/:id" element={<TestimonyDetailScreen />} />

        <Route path="/" element={<Navigate to={initialPath} replace />} />
        <Route path="*" element={<Navigate to={initialPath} replace />} />
      </Route>
    </Routes>
  );
}
