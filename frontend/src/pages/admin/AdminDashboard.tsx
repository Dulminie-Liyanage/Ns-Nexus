import { use, useEffect, useState } from "react";
import axiosInstance from "../../api/axios";
import { StatsCard } from "../../components/StatsCard";
import { Card, CardContent, CardHeader, CardTitle } from "../../components/ui/card";
import { Users, ShoppingCart, Shield, Activity } from "lucide-react";
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from "recharts";
import DashboardLayout from "../../components/DashboardLayout";
import { Switch } from "../../components/ui/switch";

const AdminDashboard = () => {
  const [users, setUsers] = useState<any[]>([]);
  const [orders, setOrders] = useState<any[]>([]);
  const [logs, setLogs] = useState<any[]>([]);

  const fetchUsers = async () => {
    try {
      const res = await axiosInstance.get("/users");
      setUsers(res.data);
    } catch (err) {
      console.error(err);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, []); 

  useEffect(() => {
    const fetchData = async () => {
      try {
        const usersRes = await axiosInstance.get("/users");
        const ordersRes = await axiosInstance.get("/orders");
        const logsRes = await axiosInstance.get("/audit-logs");

        setUsers(usersRes.data);
        setOrders(ordersRes.data);
        setLogs(logsRes.data);
      } catch (err) {
        console.error("Admin dashboard error:", err);
      }
    };

    fetchData();
  }, []);

  useEffect(() => {
  const fetchUsers = async () => {
    try {
      const res = await axiosInstance.get("/users");

      console.log("🔥 USERS FROM API:", res.data);

      setUsers(res.data);
    } catch (err) {
      console.error("❌ USERS FETCH ERROR:", err);
    }
  };

  fetchUsers();
}, []);

  const toggleUserStatus = async (userId: number) => {
    try {
      const res = await axiosInstance.put(`/users/${userId}/status`);

      const newStatus = res.data.status;

      setUsers((prev) =>
        prev.map((u) =>
          u.UserID === userId
            ? { ...u, IsLocked: newStatus }
            : u
        )
      );
    } catch (err) {
      console.error("Toggle failed:", err);
    }
  };

  const ordersByStatus = [
    { status: "Pending", count: orders.filter(o => o.status === "pending").length },
    { status: "Approved", count: orders.filter(o => o.status === "approved").length },
    { status: "Shipped", count: orders.filter(o => o.status === "shipped").length },
    { status: "Delivered", count: orders.filter(o => o.status === "delivered").length },
    { status: "Rejected", count: orders.filter(o => o.status === "rejected").length },
  ];

  const [openAdd, setOpenAdd] = useState(false);

  const [form, setForm] = useState({
    Name: "",
    Email: "",
    Role: "",
    Password: "",
    Phone: "",
    ShopName: "",
    Address: ""
  });

  const handleChange = (e: any) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const handleAddUser = async () => {
    try {
      await axiosInstance.post("/users", form);

      alert("User created successfully");

      setOpenAdd(false);

      fetchUsers(); // refresh table

    } catch (err: any) {
      console.error(err);
      alert(err.response?.data?.message || "Error creating user");
    }
  };

  return (
    <DashboardLayout role="admin">
        <div className="space-y-6">
        <div>
            <h1 className="text-2xl font-bold">Admin Dashboard</h1>
            <p className="text-muted-foreground">System overview and management</p>
        </div>
        {/* STATS */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <StatsCard title="Total Users" value={users.length} icon={<Users className="w-5 h-5" />} />
            <StatsCard title="Total Orders" value={orders.length} icon={<ShoppingCart className="w-5 h-5" />} />
            <StatsCard title="Active Users" value={users.filter(u => u.status === "active").length} icon={<Shield className="w-5 h-5" />} />
            <StatsCard title="Audit Events" value={logs.length} icon={<Activity className="w-5 h-5" />} />
        </div>

        <div className="flex justify-between items-center mb-4">
          <h2 className="text-lg font-semibold">User Accounts</h2>

          <button
            className="bg-blue-600 text-white px-4 py-2 rounded"
            onClick={() => setOpenAdd(true)}
          >
            + Add User
          </button>
        </div>

        {openAdd && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center">
            <div className="bg-white p-6 rounded-lg w-[400px] space-y-3">

              <h2 className="text-lg font-bold">Add User</h2>

              <input name="Name" placeholder="Name" onChange={handleChange} className="border p-2 w-full" />
              <input name="Email" placeholder="Email" onChange={handleChange} className="border p-2 w-full" />
              <input name="Password" placeholder="Password" onChange={handleChange} className="border p-2 w-full" />

              <select name="Role" onChange={handleChange} className="border p-2 w-full">
                <option value="admin">Admin</option>
                <option value="retailer">Retailer</option>
                <option value="driver">Warehouse Manager</option>
                <option value="driver">Logistic Manager</option>
                <option value="driver">Driver</option>
              </select>

              <input name="Phone" placeholder="Phone" onChange={handleChange} className="border p-2 w-full" />
              <input name="ShopName" placeholder="Shop Name" onChange={handleChange} className="border p-2 w-full" />
              <input name="Address" placeholder="Address" onChange={handleChange} className="border p-2 w-full" />

              <div className="flex justify-end gap-2">
                <button onClick={() => setOpenAdd(false)} className="px-3 py-1 border">
                  Cancel
                </button>

                <button onClick={handleAddUser} className="bg-green-600 text-white px-3 py-1">
                  Save
                </button>
              </div>

            </div>
          </div>
        )}

        {/* USERS TABLE */}
        <Card>
          <CardHeader>
            <CardTitle>User Accounts</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b">
                    <th className="text-left py-3 px-2 font-medium text-muted-foreground">UserID</th>
                    <th className="text-left py-3 px-2 font-medium text-muted-foreground">Email</th>
                    <th className="text-left py-3 px-2 font-medium text-muted-foreground">Role</th>
                    <th className="text-left py-3 px-2 font-medium text-muted-foreground">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {users.map((u) => (
                    <tr
                      key={u.UserID}
                      className="border-b last:border-0 hover:bg-muted/50"
                    >
                      <td className="py-3 px-2 font-medium">{u.UserID}</td>

                      <td className="py-3 px-2 text-muted-foreground">
                        {u.Email}
                      </td>

                      <td className="py-3 px-2 capitalize">
                        {u.Role}
                      </td>

                      {/* STATUS COLUMN FIXED */}
                      <td className="py-3 px-2">
                        <div className="flex items-center justify-start gap-3">
                          
                          <Switch
                            checked={u.IsLocked === 0}
                            onCheckedChange={() => {                              console.log("TOGGLE CLICKED:", u.UserID);
                              toggleUserStatus(u.UserID);
                            }}
                          />

                          <span
                            className={`text-xs font-medium ${
                              u.IsLocked === 0
                                ? "text-green-600"
                                : "text-red-500"
                            }`}
                          >
                            {u.IsLocked === 0 ? "Active" : "Inactive"}
                          </span>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
        </div>
    </DashboardLayout>
  );
};

export default AdminDashboard;