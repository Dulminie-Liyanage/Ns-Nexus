const express = require('express');
const router = express.Router();
const db = require('../config/db');

// Table already exists as: notifications(NotificationID, UserID, OrderID, Message, IsRead, CreatedAt)
// Add Title column if missing — wrapped in try-catch so module loads even if DB is slow
try {
    db.query(
        `ALTER TABLE notifications ADD COLUMN IF NOT EXISTS Title VARCHAR(100) NOT NULL DEFAULT 'Order Update'`,
        err => { if (err) console.log('Title column note:', err.message); }
    );
} catch (e) {
    console.log('notifications startup:', e.message);
}

function q(sql, params = []) {
  return new Promise((res, rej) =>
    db.query(sql, params, (err, rows) => err ? rej(err) : res(rows)));
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /notifications/:retailerId
// Returns all notifications for a retailer, newest first
// ─────────────────────────────────────────────────────────────────────────────
router.get('/:userId', async (req, res) => {
  try {
    const userId = parseInt(req.params.userId);
    if (!userId || isNaN(userId)) {
      return res.json({ notifications: [], unreadCount: 0 });
    }

    const rows = await q(
      `SELECT * FROM notifications WHERE UserID = ?
       ORDER BY CreatedAt DESC LIMIT 50`,
      [userId]);

    const unreadCount = rows.filter(n => n.IsRead == 0 || n.IsRead === false || n.IsRead === '0').length;
    res.json({ notifications: rows, unreadCount });
  } catch (err) {
    console.error('Notifications fetch error:', err.message);
    res.json({ notifications: [], unreadCount: 0 });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /notifications/log
// Backend calls this internally when order stage changes
// Body: { retailerId, orderId, title, message }
// ─────────────────────────────────────────────────────────────────────────────
router.post('/log', async (req, res) => {
  const { retailerId, orderId, title, message } = req.body;
  if (!retailerId || !message) {
    return res.status(400).json({ message: 'retailerId and message are required' });
  }
  try {
    await q(
      `INSERT INTO notifications (UserID, OrderID, Title, Message)
       VALUES (?, ?, ?, ?)`,
      [retailerId, orderId || null, title || 'Order Update', message]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ message: 'Error logging notification', error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /notifications/:retailerId/read-all
// Marks all notifications as read for a retailer
// ─────────────────────────────────────────────────────────────────────────────
router.patch('/:userId/read-all', async (req, res) => {
  try {
    const userId = parseInt(req.params.userId);
    if (!userId || isNaN(userId)) return res.json({ success: true });
    await q(`UPDATE notifications SET IsRead = 1 WHERE UserID = ?`, [userId]);
    res.json({ success: true });
  } catch (err) {
    res.json({ success: false, error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /notifications/:id/read
// Marks one notification as read
// ─────────────────────────────────────────────────────────────────────────────
router.patch('/:id/read', async (req, res) => {
  try {
    await q(`UPDATE notifications SET IsRead = 1 WHERE NotificationID = ?`,
      [req.params.id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ message: 'Error marking read', error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Exported helper — called from orders.js after every stage change
// logNotification(retailerId, orderId, stageName)
// ─────────────────────────────────────────────────────────────────────────────
const stageMessages = {
  'pending':          { title: '📋 Order Received',         msg: 'Your order #{id} has been received and is being reviewed.' },
  'approved':         { title: '✅ Order Approved',          msg: 'Great news! Order #{id} has been approved by the warehouse.' },
  'rejected':         { title: '❌ Order Rejected',          msg: 'Order #{id} has been rejected. Check the rejection reason for details.' },
  'packing':          { title: '📦 Order Being Packed',      msg: 'Order #{id} is now being packed and prepared for shipment.' },
  'in_3pl_transit':   { title: '🚛 In Transit',              msg: 'Order #{id} is on its way to the distribution hub.' },
  'ready_to_ship':    { title: '📬 Ready to Ship',           msg: 'Order #{id} is ready for final delivery to you.' },
  'out_for_delivery': { title: '🚚 Out for Delivery',        msg: 'Your order #{id} is out for delivery today! Get ready.' },
  'delivered':        { title: '🎉 Order Delivered',         msg: 'Order #{id} has been delivered. Thank you for ordering with Nestlé!' },
};

async function logNotification(retailerId, orderId, status) {
  try {
    const tmpl = stageMessages[status];
    if (!tmpl) return;
    const message = tmpl.msg.replace('{id}', orderId);
    await q(
      `INSERT INTO notifications (UserID, OrderID, Title, Message) VALUES (?, ?, ?, ?)`,
      [retailerId, orderId, tmpl.title, message]);
  } catch (e) {
    console.error('logNotification error:', e.message);
  }
}

module.exports = router;
module.exports.logNotification = logNotification;