// Release/evaluation helper for the audience-warmup HTML template. Kept outside the installed skill.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { pathToFileURL } = require('url');
const { chromium } = require(process.env.WARMUP_PLAYWRIGHT || 'playwright');

const TEMPLATE = path.join(__dirname, '..', 'skills', 'audience-warmup', 'assets', 'warmup-plan-template.html');
const DEMO = path.join(__dirname, 'evals', 'audience-warmup', 'files', 'demo-warmup-data.json');
const PAYLOAD = '<img src=x onerror="window.__xss=1">';

function withData(html, data) {
  const json = JSON.stringify(data).replace(/</g, '\\u003c');
  const placeholder = '<script type="application/json" id="warmup-data">null</script>';
  if (!html.includes(placeholder)) throw new Error('null data placeholder not found in template');
  return html.replace(placeholder, () => `<script type="application/json" id="warmup-data">${json}</script>`);
}

async function main() {
  const html = fs.readFileSync(TEMPLATE, 'utf8');
  const demo = JSON.parse(fs.readFileSync(DEMO, 'utf8'));
  const hostile = JSON.parse(JSON.stringify(demo));
  hostile.meta.title = PAYLOAD;
  hostile.days[0].topic = PAYLOAD;
  hostile.texts[0].post.text = PAYLOAD;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'warmup-html-'));
  const files = {
    demo: path.join(dir, 'demo.html'),
    hostile: path.join(dir, 'hostile.html'),
  };
  fs.writeFileSync(files.demo, withData(html, demo));
  fs.writeFileSync(files.hostile, withData(html, hostile));
  fs.writeFileSync(path.join(dir, 'empty.html'), html);

  const chromePath = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  const browser = await chromium.launch({ headless: true, ...(fs.existsSync(chromePath) ? { executablePath: chromePath } : {}) });
  const results = [];
  for (const [name, file] of Object.entries(files)) {
    const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
    const errors = [];
    const network = [];
    page.on('pageerror', e => errors.push(e.message));
    page.on('request', r => { if (/^https?:/.test(r.url())) network.push(r.url()); });
    await page.addInitScript(() => { window.print = () => { window.__printCalled = true; }; });
    await page.goto(pathToFileURL(file).href);

    const tabs = page.getByRole('tab');
    const tabNames = await tabs.allTextContents();
    const tabPanelsVisible = [];
    for (let i = 0; i < await tabs.count(); i++) {
      await tabs.nth(i).click();
      const panelId = await tabs.nth(i).getAttribute('aria-controls');
      tabPanelsVisible.push(await page.locator(`#${panelId}`).isVisible());
    }
    await tabs.first().click();
    const rows = await page.locator('[data-day-row]').count();
    const before = await page.locator('body').innerText();
    const detail = page.getByRole('button', { name: /Кратко|Подробно/ });
    if (await detail.count()) await detail.first().click();
    const after = await page.locator('body').innerText();

    const textsTab = page.getByRole('tab', { name: /Тексты/ });
    await textsTab.click();
    const copyButtons = page.locator('button', { hasText: /Копировать/ });
    const copyCount = await copyButtons.count();
    await page.evaluate(() => { Object.defineProperty(navigator, 'clipboard', { value: undefined, configurable: true }); });
    if (copyCount) await copyButtons.first().click();
    const fallbackSelection = await page.evaluate(() => window.getSelection()?.toString() || '');
    const fallbackHint = /вручную|Ctrl|Cmd|⌘|выделен/i.test(await page.locator('body').innerText());

    const printButton = page.getByRole('button', { name: /Печать|PDF/ });
    if (await printButton.count()) await printButton.first().click();
    const printCalled = await page.evaluate(() => window.__printCalled === true);
    await page.emulateMedia({ media: 'print' });
    await page.pdf({ path: `${file}.pdf`, format: 'A4', printBackground: true });
    await page.emulateMedia({ media: 'screen' });

    const xss = await page.evaluate(() => window.__xss === 1);
    const payloadShownAsText = (await page.locator('body').innerText()).includes('<img src=x');

    await page.setViewportSize({ width: 390, height: 844 });
    await tabs.first().click();
    const mobileOverflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth + 2);
    await page.screenshot({ path: `${file}.mobile.png`, fullPage: true });
    await page.setViewportSize({ width: 1280, height: 900 });
    await page.screenshot({ path: `${file}.desktop.png`, fullPage: true });

    results.push({ name, file, tabNames, tabPanelsVisible, rows, expectedRows: (name === 'demo' ? demo : hostile).days.length,
      detailChanged: before !== after, copyCount, fallbackSelection: fallbackSelection.length, fallbackHint, printCalled,
      xss, payloadShownAsText, mobileOverflow, network, errors });
    await page.close();
  }
  const emptyPage = await browser.newPage();
  const emptyErrors = [];
  emptyPage.on('pageerror', e => emptyErrors.push(e.message));
  await emptyPage.goto(pathToFileURL(path.join(dir, 'empty.html')).href);
  const emptyMessage = /пустой шаблон/i.test(await emptyPage.locator('body').innerText());
  results.push({ name: 'empty-template', emptyMessage, errors: emptyErrors });
  await browser.close();
  console.log(JSON.stringify(results, null, 2));
  const empty = results.find(r => r.name === 'empty-template');
  const pages = results.filter(r => r.name !== 'empty-template');
  const bad = !empty.emptyMessage || empty.errors.length || pages.some(r =>
    r.errors.length || r.network.length || r.mobileOverflow || !r.printCalled || !r.copyCount ||
    (!r.fallbackSelection && !r.fallbackHint) || r.rows !== r.expectedRows || !r.detailChanged ||
    r.tabNames.length !== 4 || r.tabPanelsVisible.some(v => !v) || r.xss ||
    (r.name === 'hostile' && !r.payloadShownAsText));
  if (bad) { console.error('FAIL: audience-warmup HTML template check'); process.exitCode = 1; }
  else console.log('PASS: audience-warmup HTML template works offline, safely and on mobile');
}

main().catch(e => { console.error(e); process.exitCode = 1; });
