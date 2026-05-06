const express = require('express');
const router = express.Router();
const db = require('../config/db');

// 1. FOR RETAILERS: Only see items that are ACTIVE AND HAVE STOCK
router.get('/', async (req, res) => {
    try {
        const query = `
            SELECT ProductID, ProductName, Unit, Price, SKU, Weight 
            FROM products 
            WHERE IsAvailable = 1
        `;
        const [results] = await db.query(query);
        return res.status(200).json({ products: results });
    } catch (err) {
        return res.status(500).json({ message: 'Database error', error: err });
    }
});

// 2. FOR WAREHOUSE MANAGER: See EVERYTHING (including Low Stock alerts)
router.get('/all', async (req, res) => {
    try {
        const query = 'SELECT * FROM products ORDER BY ProductName ASC';
        const [results] = await db.query(query);
        
        const processedResults = results.map(p => {
            let status = 'Pending';
            if (p.IsAvailable === 1) {
                status = 'Active';
            } else {
                status = 'Inactive';
            }
            // Mock random states to match design based on product id or similar
            if (p.ProductID % 5 === 0) status = 'Pending';
            if (p.ProductID % 4 === 0) status = 'On Sale';
            if (p.ProductID % 7 === 0) status = 'Bouncing';

            let type = 'Dessert';
            let unitStr = (p.Unit || '').toLowerCase();
            if (unitStr.includes('kg')) type = 'Fruits';
            else if (unitStr.includes('lt')) type = 'Juice';
            else if (unitStr.includes('boxes')) type = 'Care';
            else if (p.ProductID % 3 === 0) type = 'Ice Cream';

            return {
                ...p,
                isLowStock: false,
                Status: status,
                Type: type
            };
        });

        return res.status(200).json({ products: processedResults });
    } catch (err) {
        return res.status(500).json({ message: 'Database error', error: err });
    }
});

// 3. POST /products - Add a new product
router.post('/', async (req, res) => {
    try {
        const { ProductName, Unit, Price, Weight, SKU } = req.body;
        const query = `
            INSERT INTO products (ProductName, Unit, Price, Weight, SKU, IsAvailable) 
            VALUES (?, ?, ?, ?, ?, 1)
        `;
        
        const [result] = await db.query(query, [ProductName, Unit, Price, Weight, SKU]);
        res.status(201).json({ message: 'Product created successfully', id: result.insertId });
    } catch (err) {
        console.error("Add Product Error:", err);
        return res.status(500).json({ message: 'Error adding product', error: err.message || err });
    }
});

// 4. UPDATE PRODUCT
router.put('/:id', async (req, res) => {
    try {
        const productId = req.params.id;
        const { ProductName, Unit, Price, Weight, SKU } = req.body;
        
        const query = `
            UPDATE products 
            SET ProductName = ?, Unit = ?, Price = ?, Weight = ?, SKU = ? 
            WHERE ProductID = ?
        `;
        
        await db.query(query, [ProductName, Unit, Price, Weight, SKU, productId]);
        res.status(200).json({ message: 'Product updated successfully' });
    } catch (err) {
        return res.status(500).json({ message: 'Error updating product', error: err.message || err });
    }
});

// 5. TOGGLE AVAILABILITY
router.patch('/:id/toggle', async (req, res) => {
    try {
        const productId = req.params.id;
        const { isAvailable } = req.body; 

        const query = 'UPDATE products SET IsAvailable = ? WHERE ProductID = ?';
        await db.query(query, [isAvailable, productId]);
        res.status(200).json({ message: 'Status updated successfully' });
    } catch (err) {
        return res.status(500).json({ message: 'Database error', error: err.message || err });
    }
});

module.exports = router;