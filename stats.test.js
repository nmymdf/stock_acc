const test = require('node:test');
const assert = require('node:assert');
const { calcFee, calcTax, computeStats } = require('./stats.js');

test('fee and tax', () => {
  assert.strictEqual(calcFee(1000), 20);
  assert.strictEqual(calcFee(100000), 142);
  assert.strictEqual(calcTax('buy', 100000), 0);
  assert.strictEqual(calcTax('sell', 100000), 300);
});

test('per-stock statistics with moving average cost', () => {
  const trades = [
    { date: '2026-01-01', code: '2330', name: '台積電', side: 'buy', shares: 1000, price: 100, fee: 100, tax: 0 },
    { date: '2026-01-02', code: '2330', name: '台積電', side: 'buy', shares: 1000, price: 200, fee: 100, tax: 0 },
    { date: '2026-01-03', code: '2330', name: '台積電', side: 'sell', shares: 1000, price: 250, fee: 100, tax: 750 },
    { date: '2026-01-01', code: '0050', name: '', side: 'buy', shares: 10, price: 50, fee: 20, tax: 0 },
  ];
  const { rows, total } = computeStats(trades, { '2330': 300 });
  const tsmc = rows.find((r) => r.code === '2330');
  assert.strictEqual(tsmc.shares, 1000);
  assert.strictEqual(tsmc.cost, 150100);
  assert.strictEqual(tsmc.realized, 250000 - 850 - 150100);
  assert.strictEqual(tsmc.unrealized, 300000 - 150100);
  assert.strictEqual(tsmc.count, 3);
  const etf = rows.find((r) => r.code === '0050');
  assert.strictEqual(etf.unrealized, null);
  assert.strictEqual(total.cost, 150100 + 520);
});
