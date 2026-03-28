const db = require('../config/db');

exports.placeOrder = (req, res) => {
  const { retailer_id, delivery_date, is_urgent, items } = req.body;
  if (!retailer_id || !delivery_date || !items.length) return res.status(400).json({ message: 'Missing fields' });

  const orderQuery = 'INSERT INTO orders (RetailerID, Status, IsUrgent, DeliveryDate) VALUES (?, "pending", ?, ?)';
  db.query(orderQuery, [retailer_id, is_urgent ? 1 : 0, delivery_date], (err, result) => {
    if (err) return res.status(500).json({ message: 'DB error', error: err });
    const orderID = result.insertId;
    const productIds = items.map(i => i.product_id);

    const pricingQuery = 'SELECT ProductID, Price, Weight FROM products WHERE ProductID IN (?)';
    db.query(pricingQuery, [productIds], (err2, products) => {
      if (err2) return res.status(500).json({ message: 'DB error', error: err2 });

      const productMap = {};
      products.forEach(p => (productMap[p.ProductID] = p));
      const itemValues = items.map(i => [orderID, i.product_id, i.qty_requested, 0, productMap[i.product_id]?.Price || 0]);

      db.query('INSERT INTO order_items (OrderID, ProductID, QtyRequested, QtyApproved, UnitPrice) VALUES ?', [itemValues], (err3) => {
        if (err3) return res.status(500).json({ message: 'DB error', error: err3 });
        res.status(201).json({ message: 'Order placed', orderID });
      });
    });
  });
};