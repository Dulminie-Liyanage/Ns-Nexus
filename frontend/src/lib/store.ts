// lib/store.ts
import axios from "axios";

const API_BASE = "http://localhost:5000"; // or your deployed backend URL

export interface Product {
  id: string;
  name: string;
  sku: string;
  price: number;
  weight: number;
  available: boolean;
}

export interface OrderItem {
  skuId: string;
  skuName: string;
  quantity: number;
  price: number;
  weight: number;
}

export interface Order {
  id: string;
  retailerId: string;
  retailerName: string;
  items: OrderItem[];
  status: string;
  deliveryDate: string;
  totalPrice: number;
  totalWeight: number;
  createdAt: string;
  rejectionReason?: string;
  urgent?: boolean;
}

export const store = {
  // Products
  getAvailableProducts: async (): Promise<Product[]> => {
    const res = await axios.get(`${API_BASE}/products`);
    return res.data.products.map((p: any) => ({
      id: p.ProductID.toString(),
      name: p.ProductName,
      sku: p.SKU,
      price: p.Price,
      weight: p.Weight,
      available: p.IsAvailable === 1,
    }));
  },

  // Orders
  getOrders: async (retailerId: string): Promise<Order[]> => {
    const res = await axios.get(`${API_BASE}/orders/retailer/${retailerId}`);
    return res.data.orders.map((o: any) => ({
      id: o.OrderID.toString(),
      retailerId: retailerId,
      retailerName: o.RetailerName || "",
      items: [], // frontend can fetch items separately if needed
      status: o.Status,
      deliveryDate: o.DeliveryDate,
      totalPrice: o.TotalPrice,
      totalWeight: o.TotalWeight,
      createdAt: o.CreatedAt,
      rejectionReason: o.RejectionReason,
      urgent: o.IsUrgent === 1,
    }));
  },

  createOrder: async (order: any) => {
    const res = await axios.post(`${API_BASE}/orders`, order);
    return res.data;
  },

  // Optional: fetch order items separately
  getOrderItems: async (orderId: string) => {
    const res = await axios.get(`${API_BASE}/orders/${orderId}/items`);
    return res.data.items.map((i: any) => ({
      skuId: i.ProductID.toString(),
      skuName: i.ProductName,
      quantity: i.QtyRequested,
      price: i.Price,
      weight: 0, // fetch from product if needed
    }));
  },
};