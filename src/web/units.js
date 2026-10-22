// Decimal byte formatting (1 GB = 10^9 bytes, like Finder). Mirrors src/units.py;
// tests/units_cases.json keeps the Python, JavaScript and Swift copies identical.
const UNITS = [[1e12, 'TB', 2], [1e9, 'GB', 2], [1e6, 'MB', 1], [1e3, 'KB', 1]];

const fmtBytes = n => {
  if (n == null) return 'unknown';
  for (let i = 0; i < UNITS.length; i++) {
    let [size, label, digits] = UNITS[i];
    if (n >= size) {
      let text = (n / size).toFixed(digits);
      // 999,960 bytes would print "1000.0 KB"; step up to "1.0 MB" instead.
      if (Number(text) >= 1000 && i > 0) {
        [size, label, digits] = UNITS[i - 1];
        text = (n / size).toFixed(digits);
      }
      return text + ' ' + label;
    }
  }
  return Math.trunc(n) + ' B';
};

if (typeof module !== 'undefined') module.exports = { fmtBytes };
