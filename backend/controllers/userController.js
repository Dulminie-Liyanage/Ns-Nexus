import db from "../config/db.js";
import jwt from "jsonwebtoken";

// LOGIN USER 
export const loginUser = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: "Email and password are required" });
    }

    const [rows] = await db.query(
      "SELECT * FROM users WHERE Email = ?",
      [email]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: "User not found" });
    }

    const user = rows[0];

    const isMatch = password === user.PasswordHash;
    if (!isMatch) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const token = jwt.sign(
    { id: user.UserID, role: user.Role },
    "SECRET_KEY",
    { expiresIn: "1h" }
  );

    res.json({
      token,
      user: {
        id: user.UserID,
        name: user.Name,
        email: user.Email,
        role: user.Role,
        shopName: user.ShopName,
        address: user.Address,
        district: user.District,
      },
    });

  } catch (err) {
    console.error("Login error:", err);
    res.status(500).json({ error: "Login failed" });
  }
};

//  GET ALL USERS 
export const getAllUsers = async (req, res) => {
  try {
    const [rows] = await db.query("SELECT UserID, Email, Role, IsLocked FROM users");
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// UPDATE USER DETAILS
export const updateUserStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { IsLocked } = req.body;

    await db.query(
      `UPDATE users 
       SET IsLocked = ?, UpdatedAt=NOW()
       WHERE UserID= ?`,
      [IsLocked, id]
    );

    res.json({ message: "User updated successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Update failed" });
  }
};

// TOGGLE ACTIVE / INACTIVE
export const toggleUserStatus = async (req, res) => {
  try {
    const { id } = req.params;

    const [user] = await db.query(
      "SELECT IsLocked FROM users WHERE UserID=?",
      [id]
    );

    const newStatus = user[0].IsLocked === 1 ? 0 : 1;

    await db.query(
      `UPDATE users 
       SET IsLocked=?, LastStatusChange=NOW(), UpdatedAt=NOW()
       WHERE UserID=?`,
      [newStatus, id]
    );

    res.json({ message: "User status updated", status: newStatus });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

//  GET USER BY ID 
export const getUserById = async (req, res) => {
  try {
    const [rows] = await db.query(
      "SELECT UserID, Name, Email, Phone, Role, ShopName, District FROM users WHERE UserID = ?",
      [req.params.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch user" });
  }
};

//  GET ALL DRIVERS 
export const getDrivers = async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT 
        UserID AS id,
        Name AS name,
        LOWER(CurrentStatus) AS availability_status
      FROM users
      WHERE Role = 'driver'
    `);

    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch drivers" });
  }
};

//  CREATE DRIVER 
export const createDriver = async (req, res) => {
  try {
    const { name, email, phone, password } = req.body;

    if (!name || !email || !phone || !password) {
      return res.status(400).json({ message: "All fields are required" });
    }

    const [result] = await db.query(
      `INSERT INTO users 
       (Name, Email, Phone, PasswordHash, Role, CurrentStatus) 
       VALUES (?, ?, ?, ?, 'driver', 'AVAILABLE')`,
      [name, email, phone, password]
    );

    res.json({
      id: result.insertId,
      name,
      email,
      phone,
      role: "driver",
      availability_status: "available",
    });

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to create driver" });
  }
};

// UPDATE DRIVER AVAILABILITY STATUS
export const updateDriverStatus = async (req, res) => {
  const userId = req.params.id;
  const { status } = req.body; // "AVAILABLE" or "BUSY"

  if (!status) {
    return res.status(400).json({ message: "Status is required" });
  }

  try {
    await db.query(
      "UPDATE users SET CurrentStatus = ? WHERE UserID = ? AND Role = 'driver'",
      [status, userId]
    );

    res.json({ message: "Driver status updated successfully" });
  } catch (err) {
    console.error("Update driver status error:", err);
    res.status(500).json({ message: "Failed to update driver status" });
  }
};

//  GET AVAILABLE DRIVERS 
export const getAvailableDrivers = async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT 
        UserID AS id,
        Name AS name
      FROM users
      WHERE Role = 'driver' AND CurrentStatus = 'AVAILABLE'
    `);

    res.json(rows);

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch available drivers" });
  }
};

//  DRIVER SCHEDULE
export const getDriverSchedule = async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT 
         OrderID AS id,
         RetailerID,
         DeliveryDate,
         Status
       FROM orders
       WHERE DriverID = ?
       ORDER BY DeliveryDate ASC`,
      [req.params.id]
    );

    res.json(rows);

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch driver schedule" });
  }
};

// CREATE USER 
export const createUser = async (req, res) => {
  try {
    const { Name, Email, Role, Password, Phone, ShopName, Address } = req.body;

    const [existing] = await db.query(
      "SELECT * FROM users WHERE Email = ?",
      [Email]
    );

    if (existing.length > 0) {
      return res.status(400).json({ message: "Email already exists" });
    }

    await db.query(
  `INSERT INTO users 
  (Name, Email, Role, PasswordHash, Phone, ShopName, Address, IsLocked, CreatedAt, UpdatedAt)
  VALUES (?, ?, ?, ?, ?, ?, ?, 0, NOW(), NOW())`,
  [
    Name,
    Email,
    Role,
    Password, 
    Phone,
    ShopName,
    Address
  ]
);

    res.json({ message: "User created successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to create user" });
  }
};