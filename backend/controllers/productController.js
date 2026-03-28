const db = require('../config/db');

exports.getProducts = (req, res) => {
  const query = 'SELECT ProductID, ProductName, Unit, Price, SKU, Weight, StockLevel FROM products WHERE IsAvailable=1 AND StockLevel>0';
  db.query(query, (err, results) => {
    if (err) return res.status(500).json({ message: 'Database error', error: err });
    res.json({ products: results });
  });
};

exports.getAllProducts = (req, res) => {
  const query = 'SELECT * FROM products ORDER BY ProductName ASC';
  db.query(query, (err, results) => {
    if (err) return res.status(500).json({ message: 'Database error', error: err });
    const processed = results.map(p => ({ ...p, isLowStock: p.StockLevel <= 10 }));
    res.json({ products: processed });
  });
};