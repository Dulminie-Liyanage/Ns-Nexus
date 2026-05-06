const express = require('express');
const router = express.Router();
const db = require('../config/db');

// GET /users — get all users (admin)
router.get('/', (req, res) => {
    db.query(
        `SELECT UserID as id, Name, Email, Phone, Role, ShopName,
                CurrentStatus, IsLocked, CreatedAt,
                IFNULL(PriorityStatus, 0) as PriorityStatus
         FROM users ORDER BY UserID ASC`,
        (err, results) => {
            if (err) return res.status(500).json({ message: 'Database error', error: err });
            const users = results.map(u => ({
                id: u.id,
                firstName: u.Name ? u.Name.split(' ')[0] : '',
                lastName: u.Name ? u.Name.split(' ').slice(1).join(' ') : '',
                email: u.Email,
                phone: u.Phone,
                role: u.Role,
                shopName: u.ShopName || '',
                currentStatus: u.CurrentStatus || 'OFFLINE',
                isActive: u.IsLocked === 0 || u.IsLocked === null,
                priorityStatus: u.PriorityStatus === 1,
                createdAt: u.CreatedAt,
            }));
            res.status(200).json(users);
        }
    );
});

// POST /users — create new user (admin)
router.post('/', (req, res) => {
    const { firstName, lastName, email, phone, role, priorityStatus } = req.body;
    if (!firstName || !email || !role) {
        return res.status(400).json({ message: 'Missing required fields' });
    }
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
        return res.status(400).json({ message: 'Invalid email format' });
    }
    const name = (firstName + ' ' + (lastName || '')).trim();

    db.query('SELECT UserID FROM users WHERE Email = ?', [email], (err, existing) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err });
        if (existing.length > 0) {
            return res.status(409).json({ message: 'A user with this email already exists.' });
        }
        db.query(
            `INSERT INTO users
                (Name, Email, Phone, Role, PasswordHash,
                 IsLocked, LoginAttempts, ShopName, Address, District,
                 CurrentStatus, PriorityStatus)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [name, email, phone || '', role, '1234',
             0, 0, '', '', '',
             'OFFLINE', 0],
            (err2, result) => {
                if (err2) {
                    console.error('CREATE USER ERROR:', err2.message, err2.code);
                    return res.status(500).json({ message: err2.message || 'Database error', code: err2.code });
                }
                const newId = result.insertId;
                // Set PriorityStatus if retailer
                if (role === 'retailer' && priorityStatus) {
                    db.query('UPDATE users SET PriorityStatus = 1 WHERE UserID = ?', [newId], () => {});
                }
                res.status(201).json({
                    id: newId,
                    firstName,
                    lastName: lastName || '',
                    email,
                    phone: phone || '',
                    role,
                    isActive: true,
                    priorityStatus: role === 'retailer' && !!priorityStatus,
                });
            }
        );
    });
});

// PUT /users/:id — update user details including PriorityStatus
router.put('/:id', (req, res) => {
    const id = req.params.id;
    const { firstName, lastName, phone, role, priorityStatus } = req.body;
    const name = (firstName + ' ' + (lastName || '')).trim();
    const priorityVal = (priorityStatus === true || priorityStatus === 1) ? 1 : 0;

    db.query(
        'UPDATE users SET Name = ?, Phone = ?, Role = ? WHERE UserID = ?',
        [name, phone || '', role, id],
        (err) => {
            if (err) return res.status(500).json({ message: 'Database error', error: err });
            // Update PriorityStatus separately — only meaningful for retailers
            db.query(
                'UPDATE users SET PriorityStatus = ? WHERE UserID = ?',
                [priorityVal, id],
                (err2) => {
                    if (err2) console.error('PriorityStatus update failed:', err2.message);
                    res.status(200).json({
                        message: 'User updated',
                        id,
                        firstName,
                        lastName: lastName || '',
                        phone: phone || '',
                        role,
                        priorityStatus: priorityVal === 1,
                    });
                }
            );
        }
    );
});

// PATCH /users/:id/status — toggle active/inactive (IsLocked)
router.patch('/:id/status', (req, res) => {
    const { isActive } = req.body;
    db.query(
        'UPDATE users SET IsLocked = ?, LoginAttempts = 0 WHERE UserID = ?',
        [isActive ? 0 : 1, req.params.id],
        (err) => {
            if (err) return res.status(500).json({ message: 'Database error', error: err });
            res.status(200).json({ message: 'Status updated', id: req.params.id, isActive });
        }
    );
});

// GET /users/:id/priority — check priority status for urgent order validation (US-10)
router.get('/:id/priority', (req, res) => {
    db.query(
        'SELECT IFNULL(PriorityStatus, 0) as PriorityStatus FROM users WHERE UserID = ?',
        [req.params.id],
        (err, results) => {
            if (err) return res.status(500).json({ message: 'Database error', error: err });
            if (results.length === 0) return res.status(404).json({ message: 'User not found' });
            res.status(200).json({ isPriority: results[0].PriorityStatus === 1 });
        }
    );
});

module.exports = router;