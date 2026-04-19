import db from "../config/db.js";

// GET DRIVER BY ID
export const getDriverById = async (req, res) => {
  try {
    const sql = `
      SELECT 
        UserID AS id,
        Name AS name,
        Phone,
        Email,
        CurrentStatus AS availability_status
      FROM users
      WHERE Role = 'driver'
    `;

    const [rows] = await db.query(sql);
    res.json(rows);

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch drivers" });
  }
};

// GET AVAILABLE DRIVERS
export const getAvailableDrivers = async (req, res) => {
  try {
    const sql = `
      SELECT 
        UserID AS id,
        Name AS name,
        CurrentStatus AS availability_status
      FROM users
      WHERE Role = 'driver' AND CurrentStatus = 'AVAILABLE'
    `;

    const [rows] = await db.query(sql);
    res.json(rows);

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch available drivers" });
  }
};

// UPDATE DRIVER STATUS
export const updateDriverStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    const sql = `
      UPDATE users 
      SET CurrentStatus = ?, LastStatusChange = NOW()
      WHERE UserID = ?
    `;

    await db.query(sql, [status, id]);

    res.json({ message: "Driver status updated" });

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to update driver status" });
  }
};