const TRADES_KEY = 'stock_acc.trades';
const PRICES_KEY = 'stock_acc.prices';
const { calcFee, calcTax, computeStats } = StockStats;

function load(key, fallback) {
  try {
    return JSON.parse(localStorage.getItem(key)) ?? fallback;
  } catch {
    return fallback;
  }
}

function save(key, value) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {}
}

let trades = load(TRADES_KEY, []);
let prices = load(PRICES_KEY, {});

const fmt = (n, digits = 0) =>
  n == null ? '—' : n.toLocaleString('zh-TW', { minimumFractionDigits: digits, maximumFractionDigits: digits });
const pl = (n) => (n == null ? '<td>—</td>' : `<td class="${n > 0 ? 'up' : n < 0 ? 'down' : ''}">${fmt(n)}</td>`);
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

function render() {
  const { rows, total } = computeStats(trades, prices);

  document.querySelector('#stats tbody').innerHTML = rows
    .map(
      (r) => `<tr>
        <td>${esc(r.code)}</td><td>${esc(r.name)}</td>
        <td>${fmt(r.shares)}</td><td>${fmt(r.avgCost, 2)}</td><td>${fmt(r.cost)}</td>
        <td><input class="price" type="number" step="0.01" min="0" data-code="${esc(r.code)}" value="${r.price ?? ''}"></td>
        <td>${fmt(r.marketValue)}</td>${pl(r.unrealized)}${pl(r.realized)}<td>${r.count}</td>
      </tr>`
    )
    .join('') || '<tr><td colspan="10" class="empty">尚無資料</td></tr>';

  document.querySelector('#stats tfoot').innerHTML = rows.length
    ? `<tr><td colspan="4">合計</td><td>${fmt(total.cost)}</td><td></td>
        <td>${fmt(total.marketValue)}</td>${pl(total.unrealized)}${pl(total.realized)}<td></td></tr>`
    : '';

  document.querySelector('#trades tbody').innerHTML = trades
    .map((t, i) => ({ t, i }))
    .sort((a, b) => b.t.date.localeCompare(a.t.date))
    .map(({ t, i }) => {
      const amount = t.side === 'buy' ? -(t.shares * t.price + t.fee) : t.shares * t.price - t.fee - t.tax;
      return `<tr>
        <td>${esc(t.date)}</td><td>${esc(t.code)}</td><td>${esc(t.name)}</td>
        <td class="${t.side === 'buy' ? 'up' : 'down'}">${t.side === 'buy' ? '買進' : '賣出'}</td>
        <td>${fmt(t.shares)}</td><td>${fmt(t.price, 2)}</td><td>${fmt(t.fee)}</td><td>${fmt(t.tax)}</td>
        <td>${fmt(amount)}</td><td><button class="del" data-i="${i}">刪除</button></td>
      </tr>`;
    })
    .join('') || '<tr><td colspan="10" class="empty">尚無交易</td></tr>';
}

const form = document.getElementById('trade-form');
form.date.valueAsDate = new Date();

form.addEventListener('submit', (e) => {
  e.preventDefault();
  const f = new FormData(form);
  const side = f.get('side');
  const shares = Number(f.get('shares'));
  const price = Number(f.get('price'));
  const amount = shares * price;
  const code = f.get('code').trim().toUpperCase();

  if (side === 'sell') {
    const held = computeStats(trades).rows.find((r) => r.code === code)?.shares ?? 0;
    if (shares > held) {
      alert(`${code} 目前持有 ${held} 股，無法賣出 ${shares} 股`);
      return;
    }
  }

  trades.push({
    date: f.get('date'),
    code,
    name: f.get('name').trim(),
    side,
    shares,
    price,
    fee: f.get('fee') === '' ? calcFee(amount) : Number(f.get('fee')),
    tax: f.get('tax') === '' ? calcTax(side, amount) : Number(f.get('tax')),
  });
  save(TRADES_KEY, trades);
  form.reset();
  form.date.valueAsDate = new Date();
  render();
});

document.querySelector('#trades').addEventListener('click', (e) => {
  const btn = e.target.closest('.del');
  if (!btn || !confirm('確定刪除這筆交易？')) return;
  trades.splice(Number(btn.dataset.i), 1);
  save(TRADES_KEY, trades);
  render();
});

document.querySelector('#stats').addEventListener('change', (e) => {
  if (!e.target.classList.contains('price')) return;
  const v = e.target.value;
  if (v === '') delete prices[e.target.dataset.code];
  else prices[e.target.dataset.code] = Number(v);
  save(PRICES_KEY, prices);
  render();
});

render();
