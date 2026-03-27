const express = require('express');
const router = express.Router();
const db = require('../config/db');

// 1. FOR RETAILERS: Only see what is currently in stock
router.get('/', (req, res) => {
    const query = 'SELECT ProductID, ProductName, Unit, Price, SKU FROM products WHERE IsAvailable = 1';
    db.query(query, (err, results) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err });
        return res.status(200).json({ products: results });
    });
});

// 2. FOR WAREHOUSE MANAGER: See EVERYTHING (even sold out)
router.get('/all', (req, res) => {
    const query = 'SELECT ProductID, ProductName, Unit, Price, SKU, IsAvailable FROM products';
    db.query(query, (err, results) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err });
        return res.status(200).json({ products: results });
    });
});

// 3. TOGGLE AVAILABILITY: Switch between Sold Out and Available
// TOGGLE AVAILABILITY
router.patch('/:id/toggle', (req, res) => {
    const productId = req.params.id;
    const { isAvailable } = req.body; 

    // This log helps us see what the phone is sending to the server
    console.log(`Updating Product ${productId} to isAvailable: ${isAvailable}`);

    const query = 'UPDATE products SET IsAvailable = ? WHERE ProductID = ?';
    
    db.query(query, [isAvailable, productId], (err, result) => {
        if (err) {
            console.error("Database Error:", err);
            return res.status(500).json({ message: 'Failed to update', error: err });
        }
        
        if (result.affectedRows === 0) {
            return res.status(404).json({ message: 'Product not found' });
        }

        res.status(200).json({ message: 'Status updated successfully' });
    });
});

module.exports = router;