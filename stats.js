// 交易統計（移動平均成本法）。可同時在瀏覽器與 Node 使用。
(function (root) {
  const FEE_RATE = 0.001425;
  const MIN_FEE = 20;
  const TAX_RATE = 0.003;

  function calcFee(amount) {
    return Math.max(MIN_FEE, Math.floor(amount * FEE_RATE));
  }

  function calcTax(side, amount) {
    return side === 'sell' ? Math.floor(amount * TAX_RATE) : 0;
  }

  // trades: [{date, code, name, side, shares, price, fee, tax}]
  // prices: {code: currentPrice}
  function computeStats(trades, prices = {}) {
    const sorted = [...trades].sort((a, b) => a.date.localeCompare(b.date));
    const byCode = new Map();

    for (const t of sorted) {
      let s = byCode.get(t.code);
      if (!s) {
        s = { code: t.code, name: t.name || '', shares: 0, cost: 0, realized: 0, count: 0 };
        byCode.set(t.code, s);
      }
      if (t.name) s.name = t.name;
      s.count++;
      const amount = t.shares * t.price;
      if (t.side === 'buy') {
        s.shares += t.shares;
        s.cost += amount + t.fee;
      } else {
        const sold = Math.min(t.shares, s.shares);
        const avg = s.shares ? s.cost / s.shares : 0;
        const costOut = avg * sold;
        s.realized += amount - t.fee - t.tax - costOut;
        s.shares -= sold;
        s.cost -= costOut;
        if (s.shares === 0) s.cost = 0;
      }
    }

    const rows = [...byCode.values()].map((s) => {
      const price = prices[s.code];
      const hasPrice = typeof price === 'number' && !Number.isNaN(price);
      const marketValue = hasPrice ? s.shares * price : null;
      return {
        ...s,
        avgCost: s.shares ? s.cost / s.shares : 0,
        price: hasPrice ? price : null,
        marketValue,
        unrealized: hasPrice ? marketValue - s.cost : null,
      };
    });
    rows.sort((a, b) => a.code.localeCompare(b.code));

    const total = rows.reduce(
      (acc, r) => {
        acc.cost += r.cost;
        acc.realized += r.realized;
        acc.marketValue += r.marketValue ?? 0;
        acc.unrealized += r.unrealized ?? 0;
        return acc;
      },
      { cost: 0, realized: 0, marketValue: 0, unrealized: 0 }
    );

    return { rows, total };
  }

  const api = { calcFee, calcTax, computeStats };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.StockStats = api;
})(this);
