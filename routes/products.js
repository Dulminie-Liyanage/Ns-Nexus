const express = require('express');
const router = express.Router();
const db = require('../config/db');

// GET /products - retailer sees available products
router.get('/', (req, res) => {
    const query = 'SELECT ProductID, ProductName, Unit, Price FROM products WHERE IsAvailable = true';
    
    db.query(query, (err, results) => {
        if (err) {
            return res.status(500).json({ message: 'Database error', error: err });
        }
        return res.status(200).json({
            message: 'Products fetched successfully',
            products: results
        });
    });
});

module.exports = router;