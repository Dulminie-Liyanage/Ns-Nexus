import db from "../config/db.js";

export const findByemail = (email) => {
  return new Promise((resolve, reject) => {
    db.query("SELECT * FROM users WHERE Email = ?", [email], (err, result) => {
      if (err) reject(err);
      else resolve(result[0]);
    });
  });
};

export const updateAttempts = (userId, attempts, lock) => {
  return new Promise((resolve, reject) => {
    db.query(
      "UPDATE users SET failed_attempts=?, is_locked=? WHERE UserID=?",
      [attempts, lock, userId],
      (err, result) => {
        if (err) reject(err);
        else resolve(result);
      }
    );
  });
};