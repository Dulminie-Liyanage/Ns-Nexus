import { useState, useEffect } from "react";
import DashboardLayout from "../../components/DashboardLayout";
import { useAuth } from "../../lib/auth-context";
import API from "../../lib/utils"; // Centralized Axios instance
import { Card, CardContent, CardHeader, CardTitle } from "../../components/ui/card";
import { ShoppingCart, Clock, CheckCircle, XCircle } from "lucide-react";

// Define the Order interface for type safety
interface Order {
  id: string;
  createdAt: string;
  items: any[];
  totalPrice: number;
  status: "Pending" | "Approved" | "Rejected";
}

export default function RetailerDashboard() {
  const { user } = useAuth();
  const [orders, setOrders] = useState<Order[]>([]);

  useEffect(() => {
    if (!user) return;

    const fetchOrders = async () => {
      try {
        const res = await API.get<{ orders: Order[] }>(
          `/orders/retailer/${user.id}`
        );
        setOrders(res.data.orders || []);
      } catch (err) {
        console.error("Error fetching orders:", err);
      }
    };

    fetchOrders();
  }, [user]);

  const pending = orders.filter((o) => o.status === "Pending").length;
  const approved = orders.filter((o) => o.status === "Approved").length;
  const rejected = orders.filter((o) => o.status === "Rejected").length;

  const stats = [
    {
      label: "Total Orders",
      value: orders.length,
      icon: ShoppingCart,
      color: "text-primary",
    },
    {
      label: "Pending",
      value: pending,
      icon: Clock,
      color: "text-warning",
    },
    {
      label: "Approved",
      value: approved,
      icon: CheckCircle,
      color: "text-success",
    },
    {
      label: "Rejected",
      value: rejected,
      icon: XCircle,
      color: "text-destructive",
    },
  ];

  return (
    <DashboardLayout role="retailer">
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">
            Welcome back, {user?.name}!
          </h1>
          <p className="text-muted-foreground text-sm mt-1">
            Here's an overview of your orders
          </p>
        </div>

        {/* Statistics Cards */}
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {stats.map((s) => (
            <Card key={s.label}>
              <CardHeader className="flex flex-row items-center justify-between pb-2">
                <CardTitle className="text-sm font-medium text-muted-foreground">
                  {s.label}
                </CardTitle>
                <s.icon className={`h-5 w-5 ${s.color}`} />
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold">{s.value}</div>
              </CardContent>
            </Card>
          ))}
        </div>

        {/* Recent Orders Table */}
        {orders.length > 0 && (
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Recent Orders</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-border">
                      <th className="text-left py-3 px-2 font-medium text-muted-foreground">
                        Order ID
                      </th>
                      <th className="text-left py-3 px-2 font-medium text-muted-foreground">
                        Date
                      </th>
                      <th className="text-left py-3 px-2 font-medium text-muted-foreground">
                        Items
                      </th>
                      <th className="text-right py-3 px-2 font-medium text-muted-foreground">
                        Total
                      </th>
                      <th className="text-left py-3 px-2 font-medium text-muted-foreground">
                        Status
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {orders
                      .slice(-5)
                      .reverse()
                      .map((o) => (
                        <tr key={o.id} className="border-b border-border/50">
                          <td className="py-3 px-2 font-mono text-xs">
                            {o.id}
                          </td>
                          <td className="py-3 px-2">
                            {new Date(o.createdAt).toLocaleDateString()}
                          </td>
                          <td className="py-3 px-2">
                            {o.items.length} item(s)
                          </td>
                          <td className="py-3 px-2 text-right font-medium">
                            ${(o.totalPrice ?? 0).toFixed(2)}
                          </td>
                          <td className="py-3 px-2">
                            <StatusBadge status={o.status} />
                          </td>
                        </tr>
                      ))}
                  </tbody>
                </table>
              </div>
            </CardContent>
          </Card>
        )}
      </div>
    </DashboardLayout>
  );
}

function StatusBadge({ status }: { status: string }) {
  const styles: Record<string, string> = {
    Pending: "bg-orange-100 text-orange-700",
    Approved: "bg-green-100 text-green-700",
    Rejected: "bg-red-100 text-red-700",
  };

  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${
        styles[status] || "bg-gray-100 text-gray-700"
      }`}
    >
      {status}
    </span>
  );
}