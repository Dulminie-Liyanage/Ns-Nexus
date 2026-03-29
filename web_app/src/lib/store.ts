// Simple in-memory store for demo (will be replaced with Lovable Cloud DB)

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
export type OrderStatus =
  "Pending"           // Waiting for Approval
  "Approved"          // Approved
  "Packing"
  "Transit"           
  "3PL"    // In 3PL Transit
  "Out"  // Out for delivery
  "Delivered"
  "Rejected";        

export interface Order {
  id: string;
  retailerId: string;
  retailerName: string;
  items: OrderItem[];
  status: "Pending" | "Approved" | "Rejected";
  deliveryDate: string;
  totalPrice: number;
  totalWeight: number;
  createdAt: string;
  rejectionReason?: string;
  urgent?: boolean;
}

let products: Product[] = [
  { id: "p1", name: "Widget A", sku: "SKU-001", price: 25.99, weight: 0.5, available: true },
  { id: "p2", name: "Widget B", sku: "SKU-002", price: 42.50, weight: 1.2, available: true },
  { id: "p3", name: "Gadget C", sku: "SKU-003", price: 89.00, weight: 2.0, available: true },
  { id: "p4", name: "Component D", sku: "SKU-004", price: 15.75, weight: 0.3, available: false },
  { id: "p5", name: "Assembly E", sku: "SKU-005", price: 120.00, weight: 5.0, available: true },
];

let orders: Order[] = [];
let orderCounter = 1000;

export const store = {
  getProducts: () => [...products],
  getAvailableProducts: () => products.filter((p) => p.available),
  addProduct: (p: Omit<Product, "id">) => {
    const newP = { ...p, id: `p${Date.now()}` };
    products = [...products, newP];
    return newP;
  },
  toggleAvailability: (id: string) => {
    products = products.map((p) => (p.id === id ? { ...p, available: !p.available } : p));
  },

  getOrders: () => [...orders],
  getOrdersByRetailer: (retailerId: string) => orders.filter((o) => o.retailerId === retailerId),
  createOrder: (order: Omit<Order, "id" | "status" | "createdAt">) => {
    orderCounter++;
    const newOrder: Order = {
      ...order,
      id: `ORD-${orderCounter}`,
      status: "Pending",
      createdAt: new Date().toISOString(),
    };
    orders = [...orders, newOrder];
    return newOrder;
  },
  updateOrderStatus: (orderId: string, status: Order["status"], reason?: string) => {
    orders = orders.map((o) =>
      o.id === orderId ? { ...o, status, rejectionReason: reason } : o
    );
  },
};
