import { useEffect, useState } from "react";
import DashboardLayout from "../../components/DashboardLayout";
import API from "../../lib/utils";
import { Button } from "../../components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "../../components/ui/dialog";
import { Eye } from "lucide-react";

/* ================= TYPES ================= */

interface OrderItem {
  itemId: number;
  productId: number;
  skuName: string;
  quantity: number;
  unitPrice: number;
  qtyApproved?: number;
}

interface Order {
  id: number;
  retailerId: number;
  status: string;
  createdAt: string;
  deliveryDate: string;
  totalPrice: number;
  totalWeight: number;
  isUrgent: boolean;
  rejectionReason?: string;
}

/* ================= ORDER DETAILS MODAL ================= */

function OrderDetails({ order }: { order: Order }) {
  const [open, setOpen] = useState(false);
  const [items, setItems] = useState<OrderItem[]>([]);

  useEffect(() => {
    if (open) {
      API.get(`/orders/${order.id}/items`)
        .then((res: any) => {
          const mapped = res.data.map((i: any) => ({
            itemId: i.ItemID,
            productId: i.ProductID,
            skuName: i.skuName,
            quantity: i.QtyRequested,
            qtyApproved: i.QtyApproved,
            unitPrice: i.UnitPrice,
          }));

          setItems(mapped);
        })
        .catch(console.error);
    }
  }, [open, order.id]);

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="ghost" size="sm">
          <Eye className="h-4 w-4" />
        </Button>
      </DialogTrigger>

      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>Order #{order.id}</DialogTitle>
        </DialogHeader>

        <div className="space-y-3 text-sm">

          <div className="grid grid-cols-2 gap-2">
            <div><b>Retailer:</b> {order.retailerId}</div>
            <div><b>Status:</b> {order.status}</div>
            <div>
              <b>Date:</b>{" "}
              {new Date(order.createdAt).toLocaleDateString()}
            </div>
            <div>
              <b>Delivery:</b>{" "}
              {new Date(order.deliveryDate).toLocaleDateString()}
            </div>
            <div>
              <b>Total:</b> LKR {Number(order.totalPrice || 0).toFixed(2)}
            </div>
            <div>
              <b>Weight:</b> {Number(order.totalWeight || 0).toFixed(2)} kg
            </div>
          </div>

          {order.rejectionReason && (
            <div className="text-red-600 text-xs">
              <b>Rejected:</b> {order.rejectionReason}
            </div>
          )}

          {/* ================= ITEMS */}
          <div className="mt-3">
            <b>Items</b>

            {items.length === 0 ? (
              <p className="text-gray-400">No items</p>
            ) : (
              items.map((i) => (
                <div key={i.itemId} className="border-b py-2 text-xs">

                  <div className="text-gray-500">
                    Item ID: {i.itemId} | Product ID: {i.productId}
                  </div>

                  <div className="font-medium">
                    {i.skuName} × {i.quantity}
                  </div>

                  <div>
                    Unit Price: LKR {Number(i.unitPrice || 0).toFixed(2)}
                  </div>

                  {i.qtyApproved !== undefined && (
                    <div className="text-green-600">
                      Approved Qty: {i.qtyApproved}
                    </div>
                  )}

                </div>
              ))
            )}
          </div>

        </div>
      </DialogContent>
    </Dialog>
  );
}

/* ================= MAIN PAGE ================= */

export default function WarehouseOrders() {
  const [orders, setOrders] = useState<Order[]>([]);

  const fetchOrders = async () => {
    try {
      const res = await API.get("/orders");

      const formatted = res.data.map((o: any) => ({
        id: o.OrderID,
        retailerId: o.RetailerID,
        status: o.Status,
        createdAt: o.CreatedAt,
        deliveryDate: o.DeliveryDate,
        totalPrice: Number(o.TotalPrice || 0),
        totalWeight: Number(o.TotalWeight || 0),
        isUrgent: o.IsUrgent === 1,
        rejectionReason: o.RejectionReason,
      }));

      setOrders(formatted);
    } catch (err) {
      console.error(err);
    }
  };

  useEffect(() => {
    fetchOrders();
  }, []);

  /* ================= ACTIONS ================= */

  const approveOrder = async (id: number) => {
    console.log("APPROVE CLICKED:", id);

    try {
      const res = await API.put(`/orders/${id}/approve`);
      console.log("APPROVE RESPONSE:", res.data);

      await fetchOrders();
    } catch (err) {
      console.error("APPROVE ERROR:", err);
    }
  };

  const rejectOrder = async (id: number) => {
    console.log("REJECT CLICKED:", id);

    try {
      const reason = prompt("Enter rejection reason:");
      if (!reason) return;

      const res = await API.put(`/orders/${id}/reject`, { reason });

      console.log("REJECT RESPONSE:", res.data);

      await fetchOrders();
    } catch (err) {
      console.error("REJECT ERROR:", err);
    }
  };

 
  //UI 
  return (
    <DashboardLayout role="warehouse_manager">
      <div className="p-4 space-y-4">

        <h1 className="text-2xl font-bold">Warehouse Orders</h1>

        <table className="w-full text-sm border">

          <thead>
            <tr className="border-b bg-gray-100">
              <th className="p-2">Order ID</th>
              <th className="p-2">Retailer ID</th>
              <th className="p-2">Delivery Date</th>
              <th className="p-2">Total Price</th>
              <th className="p-2">Status</th>
              <th className="p-2">Priority</th>
              <th className="p-2">Actions</th>
            </tr>
          </thead>

          <tbody>
            {orders.length === 0 ? (
              <tr>
                <td colSpan={7} className="text-center p-4">
                  No orders
                </td>
              </tr>
            ) : (
              orders.map((o) => (
                <tr key={o.id} className="border-b">

                  <td className="p-2">{o.id}</td>

                  <td className="p-2">{o.retailerId}</td>

                  <td className="p-2">
                    {new Date(o.deliveryDate).toLocaleDateString()}
                  </td>

                  <td className="p-2">
                    LKR {Number(o.totalPrice).toFixed(2)}
                  </td>

                  {/* STATUS */}
                  <td className="p-2">
                    {o.status === "Approved" && (
                      <span className="text-green-600 font-semibold">
                        Approved
                      </span>
                    )}

                    {o.status === "Rejected" && (
                      <span className="text-red-600 font-semibold">
                        Rejected
                      </span>
                    )}

                    {o.status === "Pending" && (
                      <span className="text-yellow-600 font-semibold">
                        ⏳ Pending
                      </span>
                    )}
                  </td>

                  {/* PRIORITY */}
                  <td className="p-2">
                    {o.isUrgent ? (
                      <span className="text-red-600 font-bold">
                        HIGH
                      </span>
                    ) : (
                      <span className="text-gray-500">Normal</span>
                    )}
                  </td>

                  {/* ACTIONS */}
                  <td className="p-2 flex gap-2">
                    <OrderDetails order={o} />

                    <Button onClick={() => approveOrder(o.id)}>
                      Approve
                    </Button>

                    <Button onClick={() => rejectOrder(o.id)}>
                      Reject
                    </Button>
                  </td>

                </tr>
              ))
            )}
          </tbody>

        </table>
      </div>
    </DashboardLayout>
  );
}