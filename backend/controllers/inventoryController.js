import { getAllProducts, addProduct, toggleAvailability } from "../models/inventoryModel.js";
import db from "../config/db.js";

export const getProducts = async (req, res) => {
  try {
    const [results] = await db.query(`
      SELECT 
        ProductID,
        ProductName,
        SKU,
        Price,
        Weight,
        IsAvailable
      FROM products
    `);

    const products = results.map((p) => ({
      id: p.ProductID,
      name: p.ProductName,
      sku: p.SKU,
      price: p.Price,
      weight: p.Weight,
      available: p.IsAvailable === 1,
    }));

    res.json({ products });

  } catch (err) {
    console.error("DB ERROR:", err);
    res.status(500).json({ message: "Error fetching products" });
  }
};

// ADD product
export const createProduct = async (req, res) => {
  try {
    const { name, sku, price, weight, unit } = req.body;

    if (!name || !sku || !price || !weight || !unit) {
      return res.status(400).json({ message: "All fields are required" });
    }

    const result = await addProduct({ name, sku, price, weight, unit });

    res.json({
      message: "Product added successfully",
      id: result.insertId,
    });

  } catch (err) {
    console.error("DB ERROR:", err);

    // HANDLE DUPLICATE SKU
    if (err.code === "ER_DUP_ENTRY") {
      return res.status(400).json({
        message: "SKU already exists",
      });
    }

    res.status(500).json({ message: "Server error" });
  }
};

// TOGGLE availability
export const updateAvailability = async (req, res) => {
  try {
    const { id } = req.params;
    const { available } = req.body;

    const value = available ? 1 : 0;

    await toggleAvailability(id, value);

    res.json({ message: "Availability updated" });

  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};