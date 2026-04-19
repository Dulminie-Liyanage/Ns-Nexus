import userModel from "../models/userModel.js";
import jwt from "jsonwebtoken";
import bcrypt from "bcrypt";

export const login = async (req, res) => {
  const { email, password } = req.body;

  const user = await userModel.findByEmail(email);

  if (!user) {
    return res.status(401).json({ message: "User not found" });
  }

  // correct column name
  if (user.IsLocked === 1) {
    return res.status(403).json({ message: "Account is inactive" });
  }

  // password check using bcrypt
  const isMatch = await bcrypt.compare(password, user.PasswordHash);

  if (!isMatch) {
    let attempts = user.LoginAttempts + 1;
    let lock = attempts >= 3;

    await userModel.updateAttempts(user.UserID, attempts, lock);

    return res.status(401).json({ message: "Invalid password" });
  }

  // reset attempts after success
  await userModel.updateAttempts(user.UserID, 0, false);

  const token = jwt.sign(
    { id: user.UserID, role: user.Role },
    process.env.JWT_SECRET || "SECRET_KEY",
    { expiresIn: "1h" }
  );

  res.json({
    token,
    role: user.Role,
    name: user.Name,
    userId: user.UserID
  });
};