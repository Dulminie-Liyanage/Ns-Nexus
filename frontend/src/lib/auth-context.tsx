import { createContext, useContext, useState, useEffect, type ReactNode } from "react";
import axiosInstance from "../api/axios";

// Types
interface User {
  id: string;
  name: string;
  email: string;
  role: "admin" | "retailer" | "warehouse_manager" | "3pl_manager" | "driver";
}

interface LoginResponse {
  user: User;
  token: string;
}

interface LoginResult {
  success: boolean;
  message: string;
  user?: User;
}

interface AuthContextType {
  user: User | null;
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<LoginResult>;
  logout: () => void;
}

// Context
const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider = ({ children }: { children: ReactNode }) => {
  const [user, setUser] = useState<User | null>(null);

  // RESTORE SESSION ON PAGE REFRESH
  useEffect(() => {
    const savedUser = localStorage.getItem("user");
    const savedToken = localStorage.getItem("token");

    if (savedUser && savedToken) {
      setUser(JSON.parse(savedUser));
    }
  }, []);

  // LOGIN
  const login = async (
    email: string,
    password: string
  ): Promise<LoginResult> => {
    try {
      const response = await axiosInstance.post<LoginResponse>(
        "/auth/login",
        { email, password }
      );

      const data = response.data;

      setUser(data.user);

      // SAVE TO LOCAL STORAGE
      localStorage.setItem("token", data.token);
      localStorage.setItem("user", JSON.stringify(data.user));

      return {
        success: true,
        message: "Login successful",
        user: data.user,
      };
    } catch (err: any) {
      return {
        success: false,
        message:
          err.response?.data?.error ||
          err.response?.data?.message ||
          err.message ||
          "Login failed",
      };
    }
  };

  // LOGOUT
  const logout = () => {
    setUser(null);
    localStorage.removeItem("token");
    localStorage.removeItem("user");
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        isAuthenticated: !!user,
        login,
        logout,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

// Hook
export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within AuthProvider");
  }
  return context;
};