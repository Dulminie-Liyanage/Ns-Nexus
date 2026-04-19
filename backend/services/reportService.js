import db from "../config/db.js";
import { Parser } from "json2csv";

export const generateDailyReport = async () => {
  const today = new Date().toISOString().split("T")[0];

  const [orders] = await db.query(`
    SELECT o.OrderID, u.Name AS Retailer, o.Status, o.CreatedAt
    FROM orders o
    JOIN users u ON o.RetailerID = u.UserID
    WHERE DATE(o.CreatedAt) = ? AND o.Status = 'approved'
  `, [today]);

  if (!orders.length) return null;

  const parser = new Parser();
  const csv = parser.parse(orders);

  return csv;
};