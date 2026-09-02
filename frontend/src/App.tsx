import type { ReactElement } from "react";
import { Link, Navigate, NavLink, Route, Routes, useLocation } from "react-router-dom";
import "./App.css";
import Dashboard from "./pages/Dashboard";
import Accounts from "./pages/Accounts";
import Subscriptions from "./pages/Subscriptions";
import Rent from "./pages/Rent";
import IncomePage from "./pages/Income";
import Spending from "./pages/Spending";
import Affordability from "./pages/Affordability";
import Home from "./pages/Home";
import SignUp from "./pages/SignUp";
import Login from "./pages/Login";
import ForgotPassword from "./pages/ForgotPassword";
import Profile from "./pages/Profile";
import { useAuth } from "./auth/AuthContext";
import { getInitials } from "./auth/initials";
import logo from "./assets/logo-on-dark.png";

const NAV_ITEMS = [
  { to: "/dashboard", label: "Dashboard", end: true },
  { to: "/accounts", label: "Accounts" },
  { to: "/subscriptions", label: "Subscriptions" },
  { to: "/rent", label: "Rent & Utilities" },
  { to: "/income", label: "Income" },
  { to: "/spending", label: "Spending" },
  { to: "/affordability", label: "Can I Afford This?" },
];

function RequireAuth({ children }: { children: ReactElement }) {
  const { user, ready } = useAuth();
  const location = useLocation();
  if (!ready) return null;
  if (!user) return <Navigate to="/login" state={{ from: location }} replace />;
  return children;
}

const PUBLIC_PATHS = ["/", "/signup", "/login", "/forgot-password"];

function App() {
  const location = useLocation();
  const { user, ready } = useAuth();

  if (PUBLIC_PATHS.includes(location.pathname)) {
    return (
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/signup" element={<SignUp />} />
        <Route path="/login" element={<Login />} />
        <Route path="/forgot-password" element={<ForgotPassword />} />
      </Routes>
    );
  }

  if (!ready) return null;

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <Link to="/" className="brand-link">
          <img src={logo} alt="Saveup" className="brand-logo" />
        </Link>
        <nav>
          {NAV_ITEMS.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              className={({ isActive }) => (isActive ? "nav-link active" : "nav-link")}
            >
              {item.label}
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-footer">
          {user ? (
            <NavLink
              to="/profile"
              className={({ isActive }) => (isActive ? "profile-link active" : "profile-link")}
            >
              <span className="avatar">{getInitials(user.name)}</span>
              <span>{user.name}</span>
            </NavLink>
          ) : (
            <NavLink to="/login" className="nav-link">
              Log In
            </NavLink>
          )}
        </div>
      </aside>
      <main className="main-content">
        <Routes>
          <Route path="/dashboard" element={<RequireAuth><Dashboard /></RequireAuth>} />
          <Route path="/accounts" element={<RequireAuth><Accounts /></RequireAuth>} />
          <Route path="/subscriptions" element={<RequireAuth><Subscriptions /></RequireAuth>} />
          <Route path="/rent" element={<RequireAuth><Rent /></RequireAuth>} />
          <Route path="/income" element={<RequireAuth><IncomePage /></RequireAuth>} />
          <Route path="/spending" element={<RequireAuth><Spending /></RequireAuth>} />
          <Route path="/affordability" element={<RequireAuth><Affordability /></RequireAuth>} />
          <Route path="/profile" element={<RequireAuth><Profile /></RequireAuth>} />
        </Routes>
      </main>
    </div>
  );
}

export default App;
