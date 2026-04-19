import API from "../lib/utils";

// GET retailer orders (OrderHistory)
export const getRetailerOrders = async (userId: string) => {
  const res = await API.get(`/orders/retailer/${userId}`);
  return res.data.orders;
};

// GET order items 
export const getOrderItems = async (orderId: string) => {
  const res = await API.get(`/orders/${orderId}/items`);
  return res.data.items;
};

// PLACE ORDER
export const placeOrder = async (payload: any) => {
  const res = await API.post("/orders", payload);
  return res.data;
};

// GET warehouse orders (PENDING / APPROVED) 
export const getWarehouseOrders = async () => {
  const res = await API.get("/orders");
  return res.data.orders;
};

// APPROVE / REJECT ORDER 
export const updateOrderStatus = async (
  orderId: string,
  status: string,
  reason?: string
) => {
  const res = await API.put(`/orders/${orderId}`, {
    status,
    rejection_reason: reason,
  });
  return res.data;
};

// ── GET approved orders (for shipment like Flutter) ──
export const getApprovedOrders = async () => {
  const res = await API.get("/orders?status=approved");
  return res.data.orders;
};