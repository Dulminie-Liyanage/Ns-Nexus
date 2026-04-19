import db from "./config/db.js";
import bcrypt from "bcryptjs";

db.query("SELECT UserID, PasswordHash FROM users", async (err, results) => {
  if (err) {
    console.log("DB Error:", err);
    return;
  }

  for (const user of results) {
    const password = user.PasswordHash;

    // Skip already hashed passwords
    if (password.startsWith("$2a$")) {
      console.log(`User ${user.UserID} already hashed`);
      continue;
    }

    const hashed = await bcrypt.hash(password, 10);

    db.query(
      "UPDATE users SET PasswordHash = ? WHERE UserID = ?",
      [hashed, user.UserID],
      (err2) => {
        if (err2) {
          console.log("Update error:", err2);
        } else {
          console.log(`Updated user ${user.UserID}`);
        }
      }
    );
  }
});