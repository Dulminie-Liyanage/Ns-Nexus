const express = require('express');
const router = express.Router();
const db = require('../config/db');

// GET /drivers — get all users with driver role
router.get('/', (req, res) => {
    const statusFilter = req.query.status;
    const query = `
        SELECT UserID as id, Name, Email, Phone, Role,
               CurrentStatus, LastStatusChange
        FROM users WHERE Role = 'driver'
    `;
    db.query(query, (err, results) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err });
        const drivers = results.map(d => ({
            id: d.id,
            firstName: d.Name ? d.Name.split(' ')[0] : '',
            lastName: d.Name ? d.Name.split(' ').slice(1).join(' ') : '',
            email: d.Email,
            phone: d.Phone,
            status: d.CurrentStatus || 'OFFLINE',
            vehicleType: 'Van',
            currentOrders: 0,
        }));
        const filtered = statusFilter
            ? drivers.filter(d => d.status === statusFilter)
            : drivers;
        res.status(200).json(filtered);
    });
});

// GET /drivers/:id/status — get a single driver's current status
router.get('/:id/status', (req, res) => {
    db.query(
        'SELECT CurrentStatus FROM users WHERE UserID = ? AND Role = "driver"',
        [req.params.id],
        (err, results) => {
            if (err) return res.status(500).json({ message: 'Database error', error: err });
            if (results.length === 0) return res.status(404).json({ message: 'Driver not found' });
            res.status(200).json({ status: results[0].CurrentStatus || 'OFFLINE' });
        }
    );
});

// GET /drivers/:id/stats — driver time stats
router.get('/:id/stats', (req, res) => {
    res.status(200).json({
        activeMinutes: 0,
        deliveryMinutes: 0,
        breakMinutes: 0,
        offlineMinutes: 0,
    });
});

// PATCH /drivers/:id/status — update driver status (AVAILABLE/BUSY/OFFLINE/ON_BREAK)
router.patch('/:id/status', (req, res) => {
    const { status } = req.body;
    const validStatuses = ['AVAILABLE', 'BUSY', 'OFFLINE', 'ON_BREAK'];
    if (!validStatuses.includes(status)) {
        return res.status(400).json({ message: 'Invalid status. Must be AVAILABLE, BUSY, OFFLINE, or ON_BREAK' });
    }
    const query = 'UPDATE users SET CurrentStatus = ?, LastStatusChange = NOW() WHERE UserID = ? AND Role = "driver"';
    db.query(query, [status, req.params.id], (err, result) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err });
        if (result.affectedRows === 0) return res.status(404).json({ message: 'Driver not found' });
        res.status(200).json({ message: 'Status updated successfully', status });
    });
});

module.exports = router;