import nodemailer from "nodemailer";

export const sendEmail = async (fileData, filename) => {
  const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: "your_email@gmail.com",
      pass: "your_app_password",
    },
  });

  await transporter.sendMail({
    from: "your_email@gmail.com",
    to: "manager@email.com",
    subject: "Daily Order Report",
    text: "Attached is today's report.",
    attachments: [
      {
        filename: filename,
        content: fileData,
      },
    ],
  });
};