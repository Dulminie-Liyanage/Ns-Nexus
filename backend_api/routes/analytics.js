const express = require('express');
const router = express.Router();
const db = require('../config/db');

// Helper: parse date range from query params
// ?start=2025-01-01&end=2025-12-31  OR  ?range=weekly|monthly|daily
function dateWhere(query, alias = '') {
  const col = alias ? `${alias}.CreatedAt` : 'CreatedAt';
  if (query.start && query.end) {
    return { where: `${col} BETWEEN ? AND ?`, params: [query.start, query.end + ' 23:59:59'] };
  }
  if (query.range === 'daily')   return { where: `${col} >= DATE_SUB(NOW(), INTERVAL 1 DAY)`,   params: [] };
  if (query.range === 'weekly')  return { where: `${col} >= DATE_SUB(NOW(), INTERVAL 7 DAY)`,   params: [] };
  if (query.range === 'monthly') return { where: `${col} >= DATE_SUB(NOW(), INTERVAL 30 DAY)`,  params: [] };
  return { where: '1=1', params: [] };
}

function q(sql, params = []) {
  return new Promise((res, rej) =>
    db.query(sql, params, (err, rows) => err ? rej(err) : res(rows)));
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /analytics/dashboard
// Admin / WM — overall order stats + fulfillment rate
// ─────────────────────────────────────────────────────────────────────────────
router.get('/dashboard', async (req, res) => {
  try {
    const { where, params } = dateWhere(req.query, 'o');

    const [totals] = await q(
      `SELECT
         COUNT(*) AS totalOrders,
         SUM(CASE WHEN Status = 'delivered' THEN 1 ELSE 0 END) AS delivered,
         SUM(CASE WHEN Status = 'pending'   THEN 1 ELSE 0 END) AS pending,
         SUM(CASE WHEN Status = 'rejected'  THEN 1 ELSE 0 END) AS rejected,
         SUM(CASE WHEN IsUrgent = 1         THEN 1 ELSE 0 END) AS urgent,
         SUM(TotalPrice)  AS totalRevenue,
         SUM(TotalWeight) AS totalWeight
       FROM orders o WHERE ${where}`, params);

    // Fulfillment rate = delivered / (total - rejected - pending)
    const eligible = (totals.totalOrders || 0) - (totals.rejected || 0) - (totals.pending || 0);
    const fulfillmentRate = eligible > 0
      ? Math.round(((totals.delivered || 0) / eligible) * 100)
      : 0;

    // Orders per stage
    const stageRows = await q(
      `SELECT CurrentStage AS stage, COUNT(*) AS count FROM orders o WHERE ${where} GROUP BY CurrentStage ORDER BY CurrentStage`, params);

    // Recent 7 days order volume
    const trendRows = await q(
      `SELECT DATE(CreatedAt) AS day, COUNT(*) AS count
       FROM orders WHERE CreatedAt >= DATE_SUB(NOW(), INTERVAL 7 DAY)
       GROUP BY DATE(CreatedAt) ORDER BY day`);

    res.json({
      summary: { ...totals, fulfillmentRate },
      stageDistribution: stageRows,
      weeklyTrend: trendRows,
    });
  } catch (err) {
    res.status(500).json({ message: 'Analytics error', error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /analytics/demand
// Manager — top 10 products, demand trend, growth %
// ─────────────────────────────────────────────────────────────────────────────
router.get('/demand', async (req, res) => {
  try {
    const { where, params } = dateWhere(req.query, 'o');

    // Top 10 most ordered products by total qty requested
    const top10 = await q(
      `SELECT p.ProductID, p.ProductName, p.SKU, p.Unit,
              SUM(oi.QtyRequested) AS totalQty,
              SUM(oi.QtyRequested * oi.UnitPrice) AS totalValue,
              COUNT(DISTINCT oi.OrderID) AS orderCount
       FROM order_items oi
       JOIN products p ON oi.ProductID = p.ProductID
       JOIN orders o ON oi.OrderID = o.OrderID
       WHERE ${where}
       GROUP BY p.ProductID, p.ProductName, p.SKU, p.Unit
       ORDER BY totalQty DESC
       LIMIT 10`, params);

    // Demand trend — weekly aggregation of qty per product (top 5)
    // MariaDB does not allow LIMIT in IN subqueries — use JOIN instead
    const top5Ids = top10.slice(0, 5).map(p => p.ProductID);
    let trend = [];
    if (top5Ids.length > 0) {
      const placeholders = top5Ids.map(() => '?').join(',');
      trend = await q(
        `SELECT p.ProductName,
                DATE_FORMAT(o.CreatedAt, '%Y-%u') AS week,
                SUM(oi.QtyRequested) AS qty
         FROM order_items oi
         JOIN products p ON oi.ProductID = p.ProductID
         JOIN orders o ON oi.OrderID = o.OrderID
         WHERE o.CreatedAt >= DATE_SUB(NOW(), INTERVAL 8 WEEK)
           AND p.ProductID IN (${placeholders})
         GROUP BY p.ProductName, week
         ORDER BY week, qty DESC`, top5Ids);
    }

    // Growth % — compare last 30 days vs prior 30 days per product
    const growth = await q(
      `SELECT p.ProductName,
              SUM(CASE WHEN o.CreatedAt >= DATE_SUB(NOW(), INTERVAL 30 DAY) THEN oi.QtyRequested ELSE 0 END) AS recent,
              SUM(CASE WHEN o.CreatedAt < DATE_SUB(NOW(), INTERVAL 30 DAY)
                        AND o.CreatedAt >= DATE_SUB(NOW(), INTERVAL 60 DAY) THEN oi.QtyRequested ELSE 0 END) AS prior
       FROM order_items oi
       JOIN products p ON oi.ProductID = p.ProductID
       JOIN orders o ON oi.OrderID = o.OrderID
       WHERE o.CreatedAt >= DATE_SUB(NOW(), INTERVAL 60 DAY)
       GROUP BY p.ProductName`);

    const growthWithPct = growth.map(g => ({
      ...g,
      growthPct: g.prior > 0
        ? Math.round(((g.recent - g.prior) / g.prior) * 100)
        : g.recent > 0 ? 100 : 0,
    }));

    // KPIs
    const totalProducts = top10.length;
    const highDemandThreshold = top10.length > 0
      ? (top10[0].totalQty * 0.5) : 0;
    const highDemandCount = top10.filter(p => p.totalQty >= highDemandThreshold).length;

    res.json({
      top10,
      trend,
      growth: growthWithPct,
      kpis: {
        totalProducts,
        highDemandCount,
        topProduct: top10[0]?.ProductName ?? 'N/A',
        topProductQty: top10[0]?.totalQty ?? 0,
      },
    });
  } catch (err) {
    console.error('Demand analytics error:', err.message);
    res.status(500).json({ message: 'Demand analytics error', error: err.message, hint: 'Check order_items table exists and has QtyRequested column' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /analytics/bottleneck
// Warehouse Manager — orders per stage, drop-off %, avg time per stage
// ─────────────────────────────────────────────────────────────────────────────
router.get('/bottleneck', async (req, res) => {
  try {
    const { where, params } = dateWhere(req.query, 'o');

    const stageLabels = {
      1: 'Pending', 2: 'Approved', 3: 'Packing',
      4: 'In 3PL Transit', 5: 'Ready to Ship',
      6: 'Out for Delivery', 7: 'Delivered',
    };

    // Orders count per stage
    const stageRows = await q(
      `SELECT CurrentStage AS stage, COUNT(*) AS count
       FROM orders o WHERE ${where}
       GROUP BY CurrentStage ORDER BY CurrentStage`, params);

    // Avg time from order creation to current state (rough proxy for stage duration)
    // For a more accurate metric we'd need stage transition logs — using CreatedAt→now as proxy
    // Use NOW() as fallback — UpdatedAt may not exist on all rows
    const avgTime = await q(
      `SELECT CurrentStage AS stage,
              AVG(TIMESTAMPDIFF(HOUR, CreatedAt, NOW())) AS avgHours
       FROM orders o WHERE ${where}
       GROUP BY CurrentStage ORDER BY CurrentStage`, params);

    // Build full 7-stage array
    const stageMap = {};
    stageRows.forEach(r => { stageMap[r.stage] = r.count; });
    const avgMap = {};
    avgTime.forEach(r => { avgMap[r.stage] = Math.round(r.avgHours || 0); });

    const stages = [1,2,3,4,5,6,7].map(s => ({
      stage: s,
      label: stageLabels[s],
      count: stageMap[s] || 0,
      avgHours: avgMap[s] || 0,
    }));

    // Drop-off % between consecutive stages
    const dropOffs = stages.map((s, i) => {
      if (i === 0) return { ...s, dropOffPct: 0 };
      const prev = stages[i-1].count;
      const curr = s.count;
      const pct = prev > 0 ? Math.round(((prev - curr) / prev) * 100) : 0;
      return { ...s, dropOffPct: pct };
    });

    // Identify bottleneck — stage with highest avg hours
    const bottleneck = stages.reduce((max, s) =>
      s.avgHours > max.avgHours ? s : max, stages[0]);

    const totalOrders = stageMap[1] || 0;
    const delivered = stageMap[7] || 0;

    res.json({
      stages: dropOffs,
      bottleneck,
      kpis: {
        totalOrders,
        delivered,
        dropOffRate: totalOrders > 0
          ? Math.round(((totalOrders - delivered) / totalOrders) * 100) : 0,
        bottleneckStage: bottleneck.label,
        bottleneckAvgHours: bottleneck.avgHours,
      },
    });
  } catch (err) {
    console.error('Bottleneck analytics error:', err.message);
    res.status(500).json({ message: 'Bottleneck analytics error', error: err.message, hint: 'Check orders table has CurrentStage and CreatedAt columns' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /analytics/drivers
// Logistics Manager — performance rankings, on-time rate, flags
// ─────────────────────────────────────────────────────────────────────────────
router.get('/drivers', async (req, res) => {
  try {
    // Date filter applies to deliveries.AssignedAt — not users table
    // Use inline CASE to avoid WHERE on NULL rows from LEFT JOIN
    let dateFilter = '1=1';
    let dateParams = [];
    if (req.query.start && req.query.end) {
      dateFilter = 'd.AssignedAt BETWEEN ? AND ?';
      dateParams = [req.query.start, req.query.end + ' 23:59:59'];
    } else if (req.query.range === 'daily') {
      dateFilter = 'd.AssignedAt >= DATE_SUB(NOW(), INTERVAL 1 DAY)';
    } else if (req.query.range === 'weekly') {
      dateFilter = 'd.AssignedAt >= DATE_SUB(NOW(), INTERVAL 7 DAY)';
    } else if (req.query.range === 'monthly') {
      dateFilter = 'd.AssignedAt >= DATE_SUB(NOW(), INTERVAL 30 DAY)';
    }

    // Total deliveries per driver + on-time count
    // "On time" = DeliveredAt <= order's DeliveryDate
    // Use SUM with CASE so NULL rows from LEFT JOIN don't cause errors
    const drivers = await q(
      `SELECT u.UserID, u.Name, u.CurrentStatus,
              COUNT(CASE WHEN d.DeliveryID IS NOT NULL AND (${dateFilter}) THEN 1 END) AS totalDeliveries,
              SUM(CASE WHEN d.Status = 'delivered' AND (${dateFilter}) THEN 1 ELSE 0 END) AS completed,
              SUM(CASE WHEN d.Status = 'delivered'
                        AND d.DeliveredAt IS NOT NULL
                        AND o.DeliveryDate IS NOT NULL
                        AND d.DeliveredAt <= o.DeliveryDate
                        AND (${dateFilter}) THEN 1 ELSE 0 END) AS onTime
       FROM users u
       LEFT JOIN deliveries d ON u.UserID = d.DriverID
       LEFT JOIN orders o ON d.OrderID = o.OrderID
       WHERE u.Role = 'driver'
       GROUP BY u.UserID, u.Name, u.CurrentStatus
       ORDER BY completed DESC`, [...dateParams, ...dateParams, ...dateParams]);

    // Calculate on-time rate + performance score + flag
    const avgOnTimeRate = drivers.length > 0
      ? drivers.reduce((sum, d) => {
          const rate = d.completed > 0 ? (d.onTime / d.completed) * 100 : 0;
          return sum + rate;
        }, 0) / drivers.length
      : 0;

    const ranked = drivers.map((d, i) => {
      const onTimeRate = d.completed > 0
        ? Math.round((d.onTime / d.completed) * 100) : 0;
      const performanceScore = Math.round((onTimeRate * 0.7) + (Math.min(d.completed, 50) / 50 * 30));
      const isFlagged = onTimeRate < 60 && d.completed >= 3;
      return {
        ...d,
        onTimeRate,
        performanceScore,
        isFlagged,
        rank: i + 1,
      };
    }).sort((a, b) => b.performanceScore - a.performanceScore)
      .map((d, i) => ({ ...d, rank: i + 1 }));

    // Weekly trend — deliveries per driver over last 6 weeks
    const trend = await q(
      `SELECT u.Name AS driver,
              DATE_FORMAT(d.DeliveredAt, '%Y-%u') AS week,
              COUNT(*) AS deliveries
       FROM deliveries d
       JOIN users u ON d.DriverID = u.UserID
       WHERE d.Status = 'delivered'
         AND d.DeliveredAt >= DATE_SUB(NOW(), INTERVAL 6 WEEK)
       GROUP BY u.Name, week ORDER BY week`);

    const flaggedCount = ranked.filter(d => d.isFlagged).length;

    res.json({
      drivers: ranked,
      trend,
      kpis: {
        totalDrivers: ranked.length,
        avgOnTimeRate: Math.round(avgOnTimeRate),
        flaggedDrivers: flaggedCount,
        topDriver: ranked[0]?.Name ?? 'N/A',
        topDriverRate: ranked[0]?.onTimeRate ?? 0,
      },
    });
  } catch (err) {
    res.status(500).json({ message: 'Driver analytics error', error: err.message });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /analytics/export?type=dashboard|demand|bottleneck|drivers&format=csv
// Returns aggregated data as JSON for client-side CSV/PDF generation
// ─────────────────────────────────────────────────────────────────────────────
router.get('/export', async (req, res) => {
  // Client handles formatting — backend just returns the raw data
  // Flutter uses csv + pdf packages to render
  res.json({ message: 'Use /analytics/dashboard, /demand, /bottleneck, or /drivers with date filters' });
});

module.exports = router;