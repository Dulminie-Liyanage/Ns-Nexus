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
  
  // Fetch all products from backend
  getProducts: async (): Promise<Product[]> => {
    const res = await fetch("/api/products");
    if (!res.ok) throw new Error("Failed to fetch products");
    return res.json();
  },

    // Add new product
  addProduct: async (prod: Omit<Product, "id">) => {
    const res = await fetch("/api/products", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(prod),
    });
    if (!res.ok) throw new Error("Failed to create product");
    return res.json();
  },

    // Toggle availability
  toggleAvailability: async (id: string) => {
    const res = await fetch(`/api/products/${id}/toggle`, {
      method: "PATCH",
    });
    if (!res.ok) throw new Error("Failed to toggle availability");
    return res.json();
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

  // Create order
  createOrder: async (order: any) => {
    const res = await fetch("/api/orders", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(order),
    });
    if (!res.ok) throw new Error("Failed to create order");
    return res.json();
  },

  // Optional: fetch order items separately
  getOrderItems: async (orderId: string): Promise<OrderItem[]> => {
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
