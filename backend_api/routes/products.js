const express = require('express');
const router = express.Router();
const db = require('../config/db');

// GET /products — all products
router.get('/', (req, res) => {
    db.query(
        `SELECT ProductID, ProductName, SKU, Unit, Price, Weight, StockLevel, IsAvailable, CreatedAt
         FROM products
         ORDER BY ProductName ASC`,
        [], (err, results) => {
            if (err) {
                console.error('GET /products error:', err.message);
                return res.status(500).json({ message: 'Database error', error: err.message });
            }
            res.json({ products: results });
        }
    );
});

// GET /products/available — only available products for retailer order screen
router.get('/available', (req, res) => {
    db.query(
        `SELECT ProductID, ProductName, SKU, Unit, Price, Weight, StockLevel, IsAvailable, CreatedAt
         FROM products
         WHERE IsAvailable = 1 AND StockLevel > 0
         ORDER BY ProductName ASC`,
        [], (err, results) => {
            if (err) {
                console.error('GET /products/available error:', err.message);
                return res.status(500).json({ message: 'Database error', error: err.message });
            }
            res.json({ products: results });
        }
    );
});

// GET /products/:id — single product
router.get('/:id', (req, res) => {
    db.query(
        `SELECT ProductID, ProductName, SKU, Unit, Price, Weight, StockLevel, IsAvailable, CreatedAt
         FROM products WHERE ProductID = ?`,
        [req.params.id], (err, results) => {
            if (err) return res.status(500).json({ message: 'Database error', error: err.message });
            if (!results || results.length === 0) return res.status(404).json({ message: 'Product not found' });
            res.json(results[0]);
        }
    );
});

// POST /products — create product
router.post('/', (req, res) => {
    const { productName, sku, unit, price, weight, stockLevel, isAvailable } = req.body;
    if (!productName || !sku) return res.status(400).json({ message: 'ProductName and SKU required' });
    db.query(
        `INSERT INTO products (ProductName, SKU, Unit, Price, Weight, StockLevel, IsAvailable)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [productName, sku, unit || 'unit', price || 0, weight || 0, stockLevel || 0, isAvailable !== undefined ? isAvailable : 1],
        (err, result) => {
            if (err) return res.status(500).json({ message: 'Database error', error: err.message });
            res.status(201).json({ message: 'Product created', productId: result.insertId });
        }
    );
});

// PUT /products/:id — update product
router.put('/:id', (req, res) => {
    const { productName, sku, unit, price, weight, stockLevel, isAvailable } = req.body;
    db.query(
        `UPDATE products SET ProductName=?, SKU=?, Unit=?, Price=?, Weight=?, StockLevel=?, IsAvailable=?
         WHERE ProductID=?`,
        [productName, sku, unit, price, weight, stockLevel, isAvailable, req.params.id],
        (err) => {
            if (err) return res.status(500).json({ message: 'Database error', error: err.message });
            res.json({ message: 'Product updated' });
        }
    );
});

// PATCH /products/:id/availability — toggle availability
router.patch('/:id/availability', (req, res) => {
    const { isAvailable } = req.body;
    db.query(
        'UPDATE products SET IsAvailable = ? WHERE ProductID = ?',
        [isAvailable ? 1 : 0, req.params.id],
        (err) => {
            if (err) return res.status(500).json({ message: 'Database error', error: err.message });
            res.json({ message: 'Availability updated' });
        }
    );
});

module.exports = router;