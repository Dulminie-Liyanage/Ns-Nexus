import cron from "node-cron";
import db from "../config/db.js";
import { generatePDF } from "../services/pdfService.js";
import { sendEmail } from "../services/emailService.js";

export const startDailyReportJob = () => {
  cron.schedule("0 18 * * *", async () => {
    console.log("Running daily report job...");

    try {
      const today = new Date().toISOString().split("T")[0];

      const [orders] = await db.query(
        `SELECT o.OrderID, u.Name AS Retailer, o.Status, o.CreatedAt
         FROM orders o
         JOIN users u ON o.RetailerID = u.UserID
         WHERE DATE(o.CreatedAt) = ? AND o.Status = 'approved'`,
        [today]
      );

      if (!orders.length) {
        console.log("No approved orders today.");
        return;
      }

      const pdfBuffer = await generatePDF(orders);

      await sendEmail(pdfBuffer, "daily_report.pdf");

      console.log("Report sent successfully!");
    } catch (err) {
      console.error("Report job failed:", err);
    }
  });
};