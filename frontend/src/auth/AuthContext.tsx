import { createContext, useContext, useEffect, useState } from "react";
import type { ReactNode } from "react";
import { api, clearToken, getToken, setToken } from "../api/client";
import type { User } from "../types";

export type AuthUser = User;

interface AuthContextValue {
  user: AuthUser | null;
  ready: boolean;
  signUp: (username: string, name: string, email: string, password: string) => Promise<void>;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => void;
  updateEmail: (email: string) => void;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (!getToken()) {
      setReady(true);
      return;
    }
    api.auth
      .me()
      .then(setUser)
      .catch(() => clearToken())
      .finally(() => setReady(true));
  }, []);

  async function signUp(username: string, name: string, email: string, password: string) {
    const res = await api.auth.signup({ username, name, email, password });
    setToken(res.access_token);
    setUser(res.user);
  }

  async function signIn(email: string, password: string) {
    const res = await api.auth.login({ email, password });
    setToken(res.access_token);
    setUser(res.user);
  }

  function signOut() {
    clearToken();
    setUser(null);
  }

  function updateEmail(email: string) {
    setUser((prev) => (prev ? { ...prev, email } : prev));
  }

  return (
    <AuthContext.Provider value={{ user, ready, signUp, signIn, signOut, updateEmail }}>
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
