import { NavLink, Route, Routes } from "react-router-dom";
import "./App.css";
import Dashboard from "./pages/Dashboard";
import Subscriptions from "./pages/Subscriptions";
import IncomePage from "./pages/Income";
import Spending from "./pages/Spending";
import Affordability from "./pages/Affordability";

const NAV_ITEMS = [
  { to: "/", label: "Dashboard", end: true },
  { to: "/subscriptions", label: "Subscriptions" },
  { to: "/income", label: "Income" },
  { to: "/spending", label: "Spending" },
  { to: "/affordability", label: "Can I Afford This?" },
];

function App() {
  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">Budget Tracker</div>
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
      </aside>
      <main className="main-content">
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/subscriptions" element={<Subscriptions />} />
          <Route path="/income" element={<IncomePage />} />
          <Route path="/spending" element={<Spending />} />
          <Route path="/affordability" element={<Affordability />} />
        </Routes>
      </main>
    </div>
  );
}

export default App;
