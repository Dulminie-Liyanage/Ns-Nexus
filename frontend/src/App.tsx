import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Route, Routes, Navigate } from "react-router-dom";
import { Toaster as Sonner } from "./components/ui/sonner";
import { Toaster } from "./components/ui/toaster";
import { TooltipProvider } from "./components/ui/tooltip";
import { AuthProvider, useAuth } from "./lib/auth-context.tsx";
import Login from "./pages/Login";
import RetailerDashboard from "../src/pages/retailer/RetailerDashboard.tsx";
import PlaceOrder from "./pages/retailer/PlaceOrder";
import OrderHistory from "./pages/warehouse/WarehouseOrders.tsx";
import WarehouseDashboard from "./pages/warehouse/WarehouseDashboard.tsx";
import WarehouseOrders from "./pages/warehouse/WarehouseOrders.tsx";
import Inventory from "./pages/warehouse/Inventory.tsx";
import NotFound from "./pages/Notfound";
import DriverDashboard from "./pages/Driver/DriverDashboard.tsx";
import LogisticsDashboard from "./pages/logistics/logisticDashboard.tsx";
import AdminDashboard from "./pages/admin/AdminDashboard.tsx";
//import AssignDrivers from "./pages/logistics/AssignDrivers";

const queryClient = new QueryClient();

// --- 2. Update ProtectedRoute props ---
function ProtectedRoute({ 
  children, 
  role 
}: { 
  children: React.ReactNode; 
  role?: "admin" | "warehouse_manager" | "retailer" | "3pl_manager" | "driver" 
}) {
  const { user, isAuthenticated } = useAuth();

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  // TypeScript now knows user might have a role
  if (role && user?.role !== role) {
    return <Navigate to= {getDashboardRoute(user?.role)} replace />;
  }

  return <>{children}</>;
}

const getDashboardRoute = (role?: string) => {
  switch (role) {
    case "admin":
      return "/admin";
    case "retailer":
      return "/dashboard";
    case "warehouse_manager":
      return "/warehouse";
    case "3pl_manager":
      return "/logistics";
    case "driver":
      return "/driver";
    default:
      return "/login";
  }
};

function AppRoutes() {
  const { isAuthenticated, user } = useAuth();

  return (
    <Routes>
      <Route 
        path="/login" 
        element={isAuthenticated ? <Navigate to={getDashboardRoute(user?.role)} replace /> : <Login />} 
      />
      <Route 
        path="/" 
        element={<Navigate to={isAuthenticated ? (user?.role === "admin" ? "/admin" : "/dashboard") : "/login"} replace />} 
      />
      
      {/* Retailer routes */}
      <Route path="/dashboard" element={<ProtectedRoute role="retailer"><RetailerDashboard /></ProtectedRoute>} />
      <Route path="/dashboard/order" element={<ProtectedRoute role="retailer"><PlaceOrder /></ProtectedRoute>} />
      <Route path="/dashboard/history" element={<ProtectedRoute role="retailer"><OrderHistory /></ProtectedRoute>} />
      
      {/* Warehouse routes */}
      <Route path="/warehouse" element={<ProtectedRoute role="warehouse_manager"><WarehouseDashboard /></ProtectedRoute>} />
      <Route path="/warehouse/orders" element={<ProtectedRoute role="warehouse_manager"><WarehouseOrders /></ProtectedRoute>} />
      <Route path="/warehouse/inventory" element={<ProtectedRoute role="warehouse_manager"><Inventory /></ProtectedRoute>} />
      <Route path="/warehouse/manage_users" element={<ProtectedRoute role="warehouse_manager"><Inventory /></ProtectedRoute>} />

      {/* Driver routes */}
      <Route path="/driver" element={<ProtectedRoute role="driver"><DriverDashboard /></ProtectedRoute>} />
      <Route path="/driver/my_deliveries" element={<ProtectedRoute role="driver"><DriverDashboard /></ProtectedRoute>} />

      {/* 3pl routes */}
      <Route path="/logistics" element={<ProtectedRoute role="3pl_manager"><LogisticsDashboard /></ProtectedRoute>} />
      {/* <Route path="/logistics/assign_drivers" element={<ProtectedRoute role="3pl_manager"><AssignDrivers /></ProtectedRoute>} /> */}
      
      {/* Admin routes */}
      <Route path="/admin" element={<ProtectedRoute role="admin"><AdminDashboard /></ProtectedRoute>} />


      <Route path="*" element={<NotFound />} />
    </Routes>
  );
}

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <Toaster />
      <Sonner />
      <BrowserRouter>
        <AuthProvider>
          <AppRoutes />
        </AuthProvider>
      </BrowserRouter>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;