const cron = require("node-cron");

cron.schedule("0 18 * * *", async () => {
  console.log("Generating Daily Order Report...");
});