import db from "../config/db.js";

export const getAvailableProducts = (req, res) => {
  db.query(
    `SELECT ProductID as id,
            ProductName as name,
            SKU as sku,
            Price as price,
            Weight as weight,
            IsAvailable as available
     FROM products
     WHERE IsAvailable = 1`,
    (err, results) => {
      if (err) return res.status(500).json(err);
      res.json({ products: results });
    }
  );
};