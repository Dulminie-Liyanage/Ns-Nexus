const express = require('express');
const router = express.Router();
const db = require('../config/db');

// POST /auth/login
router.post('/login', (req, res) => {
    const { phone, password } = req.body;

    if (!phone || !password) {
        return res.status(400).json({ message: 'Phone and password are required' });
    }

    const query = 'SELECT * FROM users WHERE Phone = ? AND Password = ?';
    db.query(query, [phone, password], (err, results) => {
        if (err) {
            return res.status(500).json({ message: 'Database error', error: err });
        }

        if (results.length === 0) {
            return res.status(401).json({ message: 'Invalid phone or password' });
        }

        const user = results[0];

        return res.status(200).json({
            message: 'Login successful',
            user: {
                id: user.UserID,
                name: user.Name,
                role: user.Role,
                district: user.District
            }
        });
    });
});

module.exports = router;