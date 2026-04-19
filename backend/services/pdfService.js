import PDFDocument from "pdfkit";

export const generatePDF = (orders) => {
  return new Promise((resolve) => {
    const doc = new PDFDocument();
    const buffers = [];

    doc.on("data", buffers.push.bind(buffers));
    doc.on("end", () => {
      resolve(Buffer.concat(buffers));
    });

    doc.fontSize(18).text("Daily Order Report", { align: "center" });
    doc.moveDown();

    orders.forEach((o) => {
      doc
        .fontSize(12)
        .text(`Order ID: ${o.OrderID}`)
        .text(`Retailer: ${o.Retailer}`)
        .text(`Status: ${o.Status}`)
        .text(`Date: ${o.CreatedAt}`)
        .moveDown();
    });

    doc.end();
  });
};