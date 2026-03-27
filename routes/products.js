const express = require('express');
const router = express.Router();
const db = require('../config/db');

// 1. FOR RETAILERS: Only see items that are ACTIVE AND HAVE STOCK
router.get('/', (req, res) => {
    // Logic: Only show products where IsAvailable = 1 AND StockLevel is greater than 0
    const query = `
        SELECT ProductID, ProductName, Unit, Price, SKU, Weight, StockLevel 
        FROM products 
        WHERE IsAvailable = 1 AND StockLevel > 0
    `;
    db.query(query, (err, results) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err });
        return res.status(200).json({ products: results });
    });
});

// 2. FOR WAREHOUSE MANAGER: See EVERYTHING (including Low Stock alerts)
router.get('/all', (req, res) => {
    const query = 'SELECT * FROM products ORDER BY ProductName ASC';
    db.query(query, (err, results) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err });
        
        // Add a "isLowStock" helper for the Frontend to show RED text
        const processedResults = results.map(p => ({
            ...p,
            isLowStock: p.StockLevel <= 10 // Flag if stock is 10 or less
        }));

        return res.status(200).json({ products: processedResults });
    });
});

// 3. POST /products - Add a new product
router.post('/', (req, res) => {
    const { ProductName, Unit, Price, Weight, SKU, StockLevel } = req.body;
    const query = `
        INSERT INTO products (ProductName, Unit, Price, Weight, SKU, StockLevel, IsAvailable) 
        VALUES (?, ?, ?, ?, ?, ?, 1)
    `;
    
    db.query(query, [ProductName, Unit, Price, Weight, SKU, StockLevel || 0], (err, result) => {
        if (err) {
            console.error("Add Product Error:", err);
            return res.status(500).json({ message: 'Error adding product', error: err });
        }
        res.status(201).json({ message: 'Product created successfully', id: result.insertId });
    });
});

// 4. UPDATE PRODUCT
router.put('/:id', (req, res) => {
    const productId = req.params.id;
    const { ProductName, Unit, Price, Weight, SKU, StockLevel } = req.body;
    
    const query = `
        UPDATE products 
        SET ProductName = ?, Unit = ?, Price = ?, Weight = ?, SKU = ?, StockLevel = ? 
        WHERE ProductID = ?
    `;
    
    db.query(query, [ProductName, Unit, Price, Weight, SKU, StockLevel, productId], (err) => {
        if (err) return res.status(500).json({ message: 'Error updating product', error: err });
        res.status(200).json({ message: 'Product updated successfully' });
    });
});

// 5. TOGGLE AVAILABILITY
router.patch('/:id/toggle', (req, res) => {
    const productId = req.params.id;
    const { isAvailable } = req.body; 

    const query = 'UPDATE products SET IsAvailable = ? WHERE ProductID = ?';
    db.query(query, [isAvailable, productId], (err) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err });
        res.status(200).json({ message: 'Status updated successfully' });
    });
});

module.exports = router;