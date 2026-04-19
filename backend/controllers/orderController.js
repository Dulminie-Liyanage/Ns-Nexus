import db from "../config/db.js";

// PLACE ORDER
export const placeOrder = (req, res) => {
  const { items } = req.body;
  const userId = req.user.id;

  const now = new Date();
  const deliveryDate = new Date(now.getTime() + 48 * 60 * 60 * 1000); // 48 hours later

  db.query(
    "INSERT INTO orders (RetailerID, DeliveryDate) VALUES (?, ?)",
    [userId, deliveryDate],
    (err, result) => {
      if (err) return res.status(500).json(err);

      const orderId = result.insertId;

      // Insert order items
      items.forEach((item) => {
        db.query(
          "INSERT INTO order_items (OrderID, ProductID, QtyRequested) VALUES (?, ?, ?)",
          [orderId, item.productId, item.qty]
        );
      });

      res.json({ message: "Order placed successfully", orderId });
    }
  );
};


// GET ALL ORDERS (for warehouse)
export const getOrders = async (req, res) => {
  try {
    const [rows] = await db.query("SELECT * FROM orders");
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};

// GET ORDER ITEMS
export const getOrderItems = (req, res) => {
  const orderId = req.params.id;

  db.query(
    `SELECT oi.ItemID, oi.ProductID, oi.QtyRequested, oi.QtyApproved,
            p.ProductName AS skuName, p.Price
     FROM order_items oi
     JOIN products p ON oi.ProductID = p.ProductID
     WHERE oi.OrderID = ?`,
    [orderId],
    (err, results) => {
      if (err) return res.status(500).json(err);
      res.json(results);
    }
  );
};


// APPROVE ORDER
export const approveOrder = (req, res) => {
  const orderId = req.params.id;

  db.query(
    "UPDATE orders SET Status='approved' WHERE OrderID=?",
    [orderId],
    (err) => {
      if (err) return res.status(500).json(err);
      res.json({ message: "Order approved" });
    }
  );
};


// REJECT ORDER
export const rejectOrder = (req, res) => {
  const orderId = req.params.id;
  const { reason } = req.body;

  db.query(
    "UPDATE orders SET Status='rejected', RejectionReason=? WHERE OrderID=?",
    [reason, orderId],
    (err) => {
      if (err) return res.status(500).json(err);
      res.json({ message: "Order rejected" });
    }
  );
};


// ASSIGN DRIVER (FIXED - removed async/await bug)
export const assignDriver = (req, res) => {
  const { driverId } = req.body;

  db.query(
    "UPDATE orders SET DriverID = ? WHERE OrderID = ?",
    [driverId, req.params.id],
    (err) => {
      if (err) return res.status(500).json(err);
      res.json({ message: "Driver assigned" });
    }
  );
};

// GET WAREHOUSE-PRIORITIZED ORDERS
export const getWarehousePrioritizedOrders = async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT * FROM orders
    `);

    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: err.message });
  }
};

// CREATE ORDER 
export const createOrder = async (req, res) => {
  try {
    const { retailer_id, delivery_date, is_urgent, items } = req.body;

    // 1. insert order
    const [orderResult] = await db.query(
      `INSERT INTO orders 
       (RetailerID, Status, IsUrgent, DeliveryDate, CreatedAt) 
       VALUES (?, 'Pending', ?, ?, NOW())`,
      [retailer_id, is_urgent ? 1 : 0, delivery_date]
    );

    const orderId = orderResult.insertId;

    // 2. insert order items
    for (const item of items) {
      await db.query(
        `INSERT INTO order_items 
         (OrderID, ProductID, QtyRequested, UnitPrice)
         VALUES (?, ?, ?, ?)`,
        [orderId, item.productId, item.qty, item.price]
      );
    }

    res.json({ orderId });

  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Order creation failed" });
  }
};

// GET RETAILER ORDER HISTORY
export const getRetailerOrderHistory = async (req, res) => {
  const userId = req.user.id;
  try {
    // 1. get orders
    const [orders] = await db.query(
      `SELECT * FROM orders WHERE RetailerID = ? ORDER BY CreatedAt DESC`,
      [userId]
    );

    // 2. attach items to each order
    for (let order of orders) {
      const [items] = await db.query(
        `SELECT 
            oi.ItemID,
            oi.ProductID,
            oi.QtyRequested,
            oi.QtyApproved,
            oi.UnitPrice,
            p.ProductName AS skuName
         FROM order_items oi
         JOIN products p ON oi.ProductID = p.ProductID
         WHERE oi.OrderID = ?`,
        [order.OrderID]
      );

      order.items = items;
    }

    res.json({ orders });

  } catch (err) {
    console.error(err);
    res.status(500).json({ message: err.message });
  }
};