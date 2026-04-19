import { useEffect, useState } from "react";
import API from "../../api/axios";
import { StatsCard } from "../../components/StatsCard";
import { Card, CardContent, CardHeader, CardTitle } from "../../components/ui/card";
import { Users, ShoppingCart, Shield, Activity } from "lucide-react";
import DashboardLayout from "../../components/DashboardLayout";
import { Switch } from "../../components/ui/switch";
import { Button } from "../../components/ui/button";

const AdminDashboard = () => {
  const [users, setUsers] = useState<any[]>([]);
  const [orders, setOrders] = useState<any[]>([]);
  const [logs, setLogs] = useState<any[]>([]);
  const [openAdd, setOpenAdd] = useState(false);

  const [form, setForm] = useState({
      Name: "",
      Email: "",
      Phone: "",
      Password: "",
      Role: "Admin",
      ShopName: "",
      Address: "",
      District: ""  
    }
  );

  // MOVE THIS OUTSIDE
  const fetchData = async () => {
    try {
      const usersRes = await API.get("/users");
      const ordersRes = await API.get("/orders");

      setUsers(usersRes.data);
      setOrders(ordersRes.data);
    } catch (err) {
      console.error("Admin dashboard error:", err);
    }
  };

  // CALL ON LOAD
  useEffect(() => {
    fetchData();
  }, []);

  // TOGGLE USER STATUS
  const updateUserStatus = async (userId: number) => {
    try {
      await API.put(`/users/${userId}/status`);

      setUsers((prev) =>
        prev.map((u) =>
          u.UserID === userId
            ? { ...u, IsLocked: u.IsLocked === 0 ? 1 : 0 }
            : u
        )
      );
    } catch (err) {
      console.error("Toggle failed:", err);
    }
  };

  // HANDLE INPUT
  const handleChange = (e: any) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  // ADD USER
  const handleAddUser = async () => {
    console.log("SAVE CLICKED");
    try {
      const payload = {
        ...form,
        PasswordHash: form.Password
      };
      await API.post("/users", payload);

      alert("User created successfully");

      setOpenAdd(false);

      setForm({
        Name: "",
        Email: "",
        Phone: "",
        Password: "",
        Role: "Admin",
        ShopName: "",
        Address: "",
        District: ""
      });

      // NOW THIS WORKS
      fetchData();

    } catch (err: any) {
      console.error("FULL ERROR:", err.response?.data);
      alert(err.response?.data?.message || "Error creating user");
    }
  };

  return (
    <DashboardLayout role="admin">
      <div className="space-y-6">

        {/* HEADER */}
        <div>
          <h1 className="text-2xl font-bold">Admin Dashboard</h1>
          <p className="text-muted-foreground">
            System overview and management
          </p>
        </div>

        {/* STATS */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <StatsCard title="Total Users" value={users.length} icon={<Users className="w-5 h-5" />} />
          <StatsCard title="Total Orders" value={orders.length} icon={<ShoppingCart className="w-5 h-5" />} />
          <StatsCard title="Active Users" value={users.filter(u => u.IsLocked === 0).length} icon={<Shield className="w-5 h-5" />} />
          <StatsCard title="Audit Events" value={logs.length} icon={<Activity className="w-5 h-5" />} />
        </div>

        {/* ADD USER BUTTON */}
        <div className="flex justify-between items-center">
          <h2 className="text-lg font-semibold">User Accounts</h2>

          <Button onClick={() => setOpenAdd(true)}>
            + Add User
          </Button>
        </div>

        {/* ADD USER MODAL */}
        {openAdd && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center">
            <div className="bg-white p-6 rounded-lg w-[400px] space-y-3">

              <h2 className="text-lg font-bold">Add User</h2>

              <input name="Name" placeholder="Name" onChange={handleChange} className="border p-2 w-full" />
              <input name="Email" placeholder="Email" onChange={handleChange} className="border p-2 w-full" />
              <input name="Password" placeholder="Password" onChange={handleChange} className="border p-2 w-full" />

              <select name="Role" onChange={handleChange} className="border p-2 w-full">
                <option value="Admin">Admin</option>
                <option value="Retailer">Retailer</option>
                <option value="Warehouse">Warehouse Manager</option>
                <option value="Logistics">Logistic Manager</option>
                <option value="Driver">Driver</option>
              </select>

              <input name="Phone" placeholder="Phone" onChange={handleChange} className="border p-2 w-full" />
              <input name="ShopName" placeholder="Shop Name" onChange={handleChange} className="border p-2 w-full" />
              <input name="Address" placeholder="Address" onChange={handleChange} className="border p-2 w-full" />
              <input name="District" placeholder="District" onChange={handleChange} className="border p-2 w-full" />

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
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b">
                  <th className="text-left p-2">ID</th>
                  <th className="text-left p-2">Email</th>
                  <th className="text-left p-2">Role</th>
                  <th className="text-left p-2">Status</th>
                </tr>
              </thead>

              <tbody>
                {users.map((u) => (
                  <tr key={u.UserID} className="border-b">
                    <td className="p-2">{u.UserID}</td>
                    <td className="p-2">{u.Email}</td>
                    <td className="p-2 capitalize">{u.Role}</td>

                    <td className="p-2 flex items-center gap-3">
                      <Switch
                        checked={u.IsLocked === 0}
                        onCheckedChange={() => updateUserStatus(u.UserID)}
                      />

                      <span className={u.IsLocked === 0 ? "text-green-600" : "text-red-500"}>
                        {u.IsLocked === 0 ? "Active" : "Inactive"}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </CardContent>
        </Card>

      </div>
    </DashboardLayout>
  );
};

export default AdminDashboard;