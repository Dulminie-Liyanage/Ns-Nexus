const API_BASE = import.meta.env.VITE_API_URL;

export type OrderItem = {
  skuName: string;
  quantity: number;
  price: number;
};

export type Order = {
  id: string;
  retailerName: string;
  createdAt: string;
  deliveryDate: string;
  totalPrice: number;
  totalWeight: number;
  status: "Pending" | "Approved" | "Rejected";
  rejectionReason?: string;
  items: OrderItem[];
};

export interface Product {
  id: string;
  name: string;
  sku: string;
  weight: number;
  price: number;
  available: boolean;
}

export const store = {
  async getOrders(retailerId: string): Promise<Order[]> {
    try {
      const url =
        retailerId && retailerId !== "ALL"
          ? `${API_BASE}/orders?retailerId=${retailerId}`
          : `${API_BASE}/orders`;

      const res = await fetch(url, {
        headers: {
          "Content-Type": "application/json",
        },
      });

      if (!res.ok) throw new Error("Failed to fetch orders");

      const data = await res.json();
      return data.orders || [];
    } catch (err) {
      console.error("Error fetching orders:", err);
      return [];
    }
  },

  async getAvailableProducts(): Promise<Product[]> {
    try {
      const res = await fetch(`${API_BASE}/products`, {
        headers: {
          "Content-Type": "application/json",
        },
      });

      if (!res.ok) throw new Error("Failed to fetch products");

      const data = await res.json();
      return data.products || [];
    } catch (err) {
      console.error("Error fetching products:", err);
      return [];
    }
  },
};