import express from "express";
import * as orderController from "../controllers/orderController.js";
import { protect } from "../middleware/authMiddleware.js";

const router = express.Router();

// Retailer → place order
router.post("/", protect, orderController.placeOrder);

// Get orders (Warehouse)
router.get("/", protect, orderController.getOrders);

// Get retailer-specific orders
//router.get("/retailer/:id", protect, orderController.getRetailerOrders);

// Get items of a specific order
router.get("/:id/items", protect, orderController.getOrderItems);

// Approve order
router.put("/:id/approve", protect, orderController.approveOrder);

// Reject order
router.put("/:id/reject", protect, orderController.rejectOrder);

// Assign driver
router.put("/:id/assign-driver", protect, orderController.assignDriver);

// Get warehouse-prioritized orders
router.get("/warehouse-priority", protect, orderController.getWarehousePrioritizedOrders);

// Get retailer order history
router.get("/my", protect, orderController.getRetailerOrderHistory);

export default router;