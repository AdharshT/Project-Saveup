import { Link, NavLink, Route, Routes, useLocation } from "react-router-dom";
import "./App.css";
import Dashboard from "./pages/Dashboard";
import Subscriptions from "./pages/Subscriptions";
import IncomePage from "./pages/Income";
import Spending from "./pages/Spending";
import Affordability from "./pages/Affordability";
import Home from "./pages/Home";
import Profile from "./pages/Profile";
import { useAuth } from "./auth/AuthContext";
import { getInitials } from "./auth/initials";
import logo from "./assets/logo-on-dark.png";

const NAV_ITEMS = [
  { to: "/dashboard", label: "Dashboard", end: true },
  { to: "/subscriptions", label: "Subscriptions" },
  { to: "/income", label: "Income" },
  { to: "/spending", label: "Spending" },
  { to: "/affordability", label: "Can I Afford This?" },
];

function App() {
  const location = useLocation();
  const { user } = useAuth();

  if (location.pathname === "/") {
    return (
      <Routes>
        <Route path="/" element={<Home />} />
      </Routes>
    );
  }

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
            <NavLink to="/" className="nav-link">
              Sign In
            </NavLink>
          )}
        </div>
      </aside>
      <main className="main-content">
        <Routes>
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/subscriptions" element={<Subscriptions />} />
          <Route path="/income" element={<IncomePage />} />
          <Route path="/spending" element={<Spending />} />
          <Route path="/affordability" element={<Affordability />} />
          <Route path="/profile" element={<Profile />} />
        </Routes>
      </main>
    </div>
  );
}

export default App;
