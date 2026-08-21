import { createContext, useContext, useEffect, useState } from "react";
import type { ReactNode } from "react";

export interface AuthUser {
  name: string;
  email: string;
}

interface AuthContextValue {
  user: AuthUser | null;
  signUp: (user: AuthUser) => void;
  updateEmail: (email: string) => void;
}

const STORAGE_KEY = "saveup.user";

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(() => {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as AuthUser) : null;
  });

  useEffect(() => {
    if (user) {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(user));
    } else {
      localStorage.removeItem(STORAGE_KEY);
    }
  }, [user]);

  function signUp(newUser: AuthUser) {
    setUser(newUser);
  }

  function updateEmail(email: string) {
    setUser((prev) => (prev ? { ...prev, email } : prev));
  }

  return (
    <AuthContext.Provider value={{ user, signUp, updateEmail }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return ctx;
}
