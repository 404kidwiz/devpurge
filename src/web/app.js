'use strict';
const $ = id => document.getElementById(id);
const token = location.hash.slice(1) || sessionStorage.getItem('devpurge-token');
if (location.hash) { sessionStorage.setItem('devpurge-token', token); history.replaceState(null, '', '/'); }
let targets = [], selected = new Set(), filter = 'all', busy = false, plan = null;
const bytes = n => n == null ? 'Unknown' : n >= 1073741824 ? (n / 1073741824).toFixed(2) + ' GiB' : (n / 1048576).toFixed(1) + ' MiB';
const titleFor = t => t.category === 'browsers' ? t.path.split('/Caches/').pop().replaceAll('/', ' / ') : label(t) + ' / ' + t.path.split('/').slice(-2).join('/');
const label = t => ({browsers:'Browser cache', installers:'App installer', oldstores:'pnpm store', review:'Retained storage'}[t.category] || t.category);
const say = (message, error = false) => { $('status').textContent = message; $('status').classList.toggle('error', error); };
function node(tag, text, className) { const el = document.createElement(tag); if (text != null) el.textContent = text; if (className) el.className = className; return el; }
async function api(path, data = {}) {
  const response = await fetch('/api/' + path, { method:'POST', headers:{'Content-Type':'application/json','X-DevPurge-Token':token || ''}, body:JSON.stringify(data) });
  const result = await response.json();
  if (!response.ok) throw new Error(result.error || 'Request failed');
  return result;
}
function setBusy(value) { busy = value; $('scan').disabled = value; $('rescue').disabled = value; $('execute').disabled = value; $('targets').setAttribute('aria-busy', String(value)); render(); }
function updateSelection() {
  const chosen = targets.filter(t => selected.has(t.id));
  $('selected').textContent = chosen.length ? chosen.length + ' location' + (chosen.length === 1 ? '' : 's') + ' selected' : 'Nothing selected';
  $('selection-size').textContent = chosen.length ? bytes(chosen.reduce((sum,t) => sum + (t.size_bytes || 0),0)) + ' stored' + (chosen.some(t => t.size_bytes == null) ? ' + unknown sizes' : '') + ' · Actual savings may differ.' : 'Stored sizes are not guaranteed freed space.';
  $('review').disabled = busy || !chosen.length;
}
function render() {
  const search = $('search').value.toLowerCase();
  const visible = targets.filter(t => (filter === 'all' || (filter === 'eligible' ? t.status === 'eligible' : t.status !== 'eligible')) && (t.path + ' ' + label(t)).toLowerCase().includes(search));
  $('targets').replaceChildren();
  for (const t of visible) {
    const row = node('div', null, 'target');
    const box = node('input'); box.type = 'checkbox'; box.checked = selected.has(t.id); box.disabled = busy || t.status !== 'eligible'; box.id = 'target-' + t.id;
    box.setAttribute('aria-label', 'Select ' + t.path); box.setAttribute('aria-describedby', 'reason-' + t.id);
    box.addEventListener('change', () => { box.checked ? selected.add(t.id) : selected.delete(t.id); updateSelection(); });
    const detail = node('div'); const title = node('label', titleFor(t), 'target-name'); title.htmlFor = box.id;
    detail.append(title, node('span', t.path, 'path'));
    const reason = node('p', t.reason + (t.size_error ? ' · ' + t.size_error : ''), 'reason'); reason.id = 'reason-' + t.id; detail.append(reason);
    row.append(box, detail, node('span', {'eligible':'Eligible','in-use':'In use','review':'Review','ignored':'Ignored'}[t.status] || t.status, 'badge ' + t.status), node('span', bytes(t.size_bytes), 'size'));
    $('targets').append(row);
  }
  $('empty').hidden = visible.length > 0;
  if (targets.length && !visible.length) { $('empty').querySelector('h3').textContent = 'No matching locations.'; $('empty').querySelector('p').textContent = 'Try another filter or search.'; }
  updateSelection();
}
$('scan').addEventListener('click', async () => {
  selected.clear(); targets = []; plan = null; $('stored').textContent='—'; $('eligible').textContent='—'; $('scan-time').textContent='Scanning…'; setBusy(true); say('Scanning local storage and checking app activity. This can take a minute…');
  $('empty').querySelector('h3').textContent = 'Taking a closer look…'; $('empty').querySelector('p').textContent = 'Reading sizes and checking activity. Your files stay unchanged.';
  try {
    const data = await api('scan'); targets = data.targets; $('rescue').checked = data.rescue;
    $('free').textContent = bytes(data.disk.free); $('stored').textContent = bytes(targets.reduce((s,t) => s + (t.size_bytes || 0),0)) + (targets.some(t => t.size_bytes == null) ? ' + ?' : '');
    $('eligible').textContent = targets.filter(t => t.status === 'eligible').length;
    $('disk-meter').style.width = (100 * (1 - data.disk.free/data.disk.total)) + '%'; $('disk-detail').textContent = bytes(data.disk.total - data.disk.free) + ' used of ' + bytes(data.disk.total);
    $('scan-time').textContent = 'Scanned ' + new Date(data.scanned_at * 1000).toLocaleTimeString([], {hour:'2-digit',minute:'2-digit'});
    say('Scan complete. Nothing selected, nothing changed.');
    $('empty').querySelector('h3').textContent = 'No supported locations found.'; $('empty').querySelector('p').textContent = 'This scan covers known cache locations, not every file on your disk.';
  } catch(error) { $('scan-time').textContent='Scan failed'; say(error.message,true); $('empty').querySelector('h3').textContent = 'The scan couldn’t finish.'; $('empty').querySelector('p').textContent = 'Your files have not been cleaned. Check the message above and try again.'; }
  finally { setBusy(false); }
});
$('review').addEventListener('click', async () => {
  setBusy(true);
  try {
    const data = await api('preview', {ids:[...selected],rescue:$('rescue').checked}); plan = data.plan;
    $('mode-note').textContent = data.rescue ? 'Selected files will move to Trash. Space is freed only after you empty Trash.' : 'Selected cache files will be permanently removed. pnpm stores will use native pruning. Future use may require downloads.';
    $('execute').textContent = data.rescue ? 'Move to Trash' : 'Clean selected items';
    $('preview-list').replaceChildren(...data.targets.map(t => { const item = node('li'); item.append(node('strong',bytes(t.size_bytes)),node('span',t.path,'path')); return item; }));
    $('confirm').showModal(); $('cancel').focus();
  } catch(error) { say(error.message,true); }
  finally { setBusy(false); }
});
$('cancel').addEventListener('click', () => $('confirm').close());
$('confirm').addEventListener('close', () => $('review').focus());
$('execute').addEventListener('click', async () => {
  if (busy || !plan) return;
  const current = plan; plan = null; $('confirm').close(); setBusy(true); say('Rechecking your selection and cleaning eligible items…');
  try {
    const data = await api('clean', {plan:current}); $('free').textContent = bytes(data.free); $('results').replaceChildren();
    for (const item of data.results) { const row = node('div',null,'result'); row.append(node('strong',item.result),node('span',item.path,'path')); $('results').append(row); }
    $('results-section').hidden = false;
    const failed = data.results.some(x => x.result.startsWith('FAILED'));
    say(failed ? 'Cleanup finished with an error. Review results below, then scan again.' : 'Cleanup finished. Review results below. Scan again for current sizes.',failed);
  } catch(error) { say(error.message + ' Some actions may have completed; scan again before retrying.',true); }
  finally { selected.clear(); targets=[]; $('stored').textContent='—'; $('eligible').textContent='—'; $('scan-time').textContent='Scan again to refresh'; $('empty').querySelector('h3').textContent='Ready for a fresh scan.'; $('empty').querySelector('p').textContent='Scan again to see what remains.'; setBusy(false); }
});
$('search').addEventListener('input',render);
document.querySelectorAll('[data-filter]').forEach(button => button.addEventListener('click', () => { filter=button.dataset.filter; document.querySelectorAll('[data-filter]').forEach(b => b.setAttribute('aria-pressed',String(b===button))); render(); }));
const initialTheme = localStorage.getItem('devpurge-theme') || (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark':'light');
document.documentElement.dataset.theme=initialTheme;
$('theme').addEventListener('click', () => { const theme=document.documentElement.dataset.theme==='dark'?'light':'dark'; document.documentElement.dataset.theme=theme; localStorage.setItem('devpurge-theme',theme); });
if (!token) { say('Open this dashboard using devpurge --gui to start a local session.',true); $('scan').disabled=true; }
