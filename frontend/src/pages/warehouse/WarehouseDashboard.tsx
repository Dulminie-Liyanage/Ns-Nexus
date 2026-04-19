import { useState, useEffect } from "react";
import DashboardLayout from "../../components/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle } from "../../components/ui/card";
import { ClipboardList, Package, CheckCircle, XCircle, Clock, ShoppingCart } from "lucide-react";
import axiosInstance from "../../api/axios";

export default function WarehouseDashboard() {
  const [orders, setOrders] = useState<any[]>([]);
  const [products, setProducts] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [ordersRes, productsRes] = await Promise.all([
          axiosInstance.get("/orders/warehouse-priority"),
          axiosInstance.get("/products") // adjust if needed
        ]);

        // sort VIP first (safety layer in frontend too)
        const sortedOrders = ordersRes.data.sort(
          (a: any, b: any) => b.priorityStatus - a.priorityStatus
        );

        setOrders(sortedOrders);
        setProducts(productsRes.data);
      } catch (err) {
        console.error("Dashboard error:", err);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  const pending = orders.filter((o) => o.status === "Pending").length;
  const approved = orders.filter((o) => o.status === "Approved").length;
  const rejected = orders.filter((o) => o.status === "Rejected").length;

  const stats = [
    { label: "Total Orders", value: orders.length, icon: ClipboardList },
    { label: "Pending Review", value: pending, icon: Clock },
    { label: "Approved", value: approved, icon: CheckCircle },
    { label: "Rejected", value: rejected, icon: XCircle },
    { label: "Total SKUs", value: products.length, icon: Package },
    {
      label: "In Stock",
      value: products.filter((p) => p.available).length,
      icon: ShoppingCart
    }
  ];

  if (loading)
    return (
      <DashboardLayout role="warehouse_manager">
        <p className="p-6">Loading dashboard...</p>
      </DashboardLayout>
    );

  return (
    <DashboardLayout role="warehouse_manager">
      <div className="space-y-6">

        <div>
          <h1 className="text-2xl font-bold">Warehouse Dashboard</h1>
          <p className="text-muted-foreground text-sm mt-1">
            Warehouse operations overview
          </p>
        </div>

        {/* STATS */}
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {stats.map((s) => (
            <Card key={s.label}>
              <CardHeader className="flex flex-row items-center justify-between pb-2">
                <CardTitle className="text-sm text-muted-foreground">
                  {s.label}
                </CardTitle>
                <s.icon className="h-5 w-5 text-primary" />
              </CardHeader>
              <CardContent>
                <div className="text-3xl font-bold">{s.value}</div>
              </CardContent>
            </Card>
          ))}
        </div>

        {/* ORDERS TABLE */}
        {orders.filter((o) => o.status === "Pending").length > 0 && (
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Pending Orders (Priority Queue)</CardTitle>
            </CardHeader>

            <CardContent>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b">
                      <th className="text-left py-3 px-2">Order ID</th>
                      <th className="text-left py-3 px-2">Retailer</th>
                      <th className="text-left py-3 px-2">Items</th>
                      <th className="text-right py-3 px-2">Total</th>
                      <th className="text-left py-3 px-2">Delivery</th>
                      <th className="text-left py-3 px-2">Priority</th>
                    </tr>
                  </thead>

                  <tbody>
                    {orders
                      .filter((o) => o.status === "Pending")
                      .map((o) => (
                        <tr key={o.id} className="border-b">

                          <td className="py-3 px-2 font-mono text-xs">
                            {o.id}
                          </td>

                          <td className="py-3 px-2">
                            {o.retailerName}
                          </td>

                          <td className="py-3 px-2">
                            {o.items?.length || 0}
                          </td>

                          <td className="py-3 px-2 text-right">
                            ${o.totalPrice?.toFixed(2)}
                          </td>

                          <td className="py-3 px-2">
                            {new Date(o.deliveryDate).toLocaleDateString()}
                          </td>

                          {/* ✅ US-10 PRIORITY FEATURE */}
                          <td className="py-3 px-2">
                            <span
                              className={`px-2 py-1 text-xs rounded-full ${
                                o.priorityStatus === 1
                                  ? "bg-red-100 text-red-700 font-bold"
                                  : "bg-gray-100 text-gray-500"
                              }`}
                            >
                              {o.priorityStatus === 1
                                ? "HIGH PRIORITY"
                                : "NORMAL"}
                            </span>
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