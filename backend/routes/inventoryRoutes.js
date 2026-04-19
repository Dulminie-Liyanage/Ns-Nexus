import express from "express";
import { getProducts, createProduct, updateAvailability } from "../controllers/inventoryController.js";

const router = express.Router();

// GET all products
router.get("/products", getProducts);

// ADD new product
router.post("/products", createProduct);

// UPDATE product availability
router.put("/products/:id/availability", updateAvailability);

console.log("Product routes loaded");

export default router;