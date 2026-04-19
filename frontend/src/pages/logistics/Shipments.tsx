import { useEffect, useState } from "react";
import {
  getWarehouseOrders,
  updateOrderStatus,
} from "../../serv/orderServices";

export default function WarehouseOrder() {
  const [orders, setOrders] = useState<any[]>([]);

  const load = async () => {
    const data = await getWarehouseOrders();
    setOrders(data);
  };

  useEffect(() => {
    load();
  }, []);

  const approve = async (id: string) => {
    await updateOrderStatus(id, "approved");
    alert("Order Approved");
    load();
  };

  const reject = async (id: string) => {
    const reason = prompt("Rejection reason?");
    await updateOrderStatus(id, "rejected", reason || "");
    alert("Order Rejected");
    load();
  };

  return (
    <div>
      <h2>Warehouse Orders</h2>

      {orders.map((o) => (
        <div key={o.OrderID} style={{ border: "1px solid gray", margin: 10 }}>
          <p>Order ID: {o.OrderID}</p>
          <p>Status: {o.Status}</p>

          <button onClick={() => approve(o.OrderID)}>Approve</button>
          <button onClick={() => reject(o.OrderID)}>Reject</button>
        </div>
      ))}
    </div>
  );
}