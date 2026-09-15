// Release/evaluation helper, kept outside the installed skill.
const fs = require('fs');
const { pathToFileURL } = require('url');
const { chromium } = require(process.env.PACKAGING_PLAYWRIGHT || 'playwright');

async function main() {
  const chromePath = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  const browser = await chromium.launch({ headless: true, ...(fs.existsSync(chromePath) ? { executablePath: chromePath } : {}) });
  const results = [];
  for (const file of process.argv.slice(2)) {
    const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
    const errors = [];
    const network = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('request', request => { if (/^https?:/.test(request.url())) network.push(request.url()); });
    await page.addInitScript(() => { window.print = () => { window.__printCalled = true; }; });
    await page.goto(pathToFileURL(file).href);
    await page.setViewportSize({ width: 390, height: 844 });
    await page.screenshot({ path: `${file}.viewport.png` });
    await page.setViewportSize({ width: 1280, height: 900 });
    const title = await page.title();
    const body = await page.locator('body').innerText();
    const controls = await page.locator('button').allTextContents();
    const before = await page.locator('body').innerText();
    const detailButtons = page.getByRole('button', { name: /Кратко|Подробно/i });
    for (let i = 0; i < await detailButtons.count(); i++) await detailButtons.nth(i).click();
    const after = await page.locator('body').innerText();
    const detailsCount = await page.locator('details').count();
    for (let i = 0; i < detailsCount; i++) {
      const details = page.locator('details').nth(i);
      if (!await details.evaluate(el => el.open)) await details.locator('summary').click();
    }
    const allDetailsOpen = await page.locator('details').evaluateAll(items => items.every(el => el.open));
    const copyButtons = await page.locator('button').filter({ hasText: /копир/i }).elementHandles();
    const copies = [];
    for (const button of copyButtons) {
      const hiddenPanel = await button.evaluate(el => el.closest('section[hidden]')?.id || '');
      if (hiddenPanel) {
        const showPanel = page.locator(`button[aria-controls="${hiddenPanel}"]`);
        if (await showPanel.count()) await showPanel.click();
      }
      await button.click();
      copies.push(await page.locator('body').innerText());
    }
    await page.evaluate(() => { Object.defineProperty(navigator, 'clipboard', { value: undefined, configurable: true }); });
    if (copyButtons.length) {
      const hiddenPanel = await copyButtons[0].evaluate(el => el.closest('section[hidden]')?.id || '');
      if (hiddenPanel) await page.locator(`button[aria-controls="${hiddenPanel}"]`).click();
      await copyButtons[0].click();
    }
    const fallbackSelection = await page.evaluate(() => window.getSelection()?.toString() || '');
    const fallbackText = await page.locator('body').innerText();
    const printButtons = page.getByRole('button', { name: /печать|PDF/i });
    await page.locator('details').evaluateAll(items => items.forEach(el => { el.open = false; }));
    if (await printButtons.count()) await printButtons.first().click();
    const printCalled = await page.evaluate(() => window.__printCalled === true);
    await page.emulateMedia({ media: 'print' });
    await page.pdf({ path: `${file}.pdf`, format: 'A4', printBackground: true });
    const printBody = await page.locator('body').innerText();
    await page.emulateMedia({ media: 'screen' });
    await page.setViewportSize({ width: 390, height: 844 });
    const mobileOverflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth + 2);
    await page.screenshot({ path: `${file}.mobile.png`, fullPage: true });
    results.push({ file, title, body_chars: body.length, controls, detail_text_changed: before !== after,
      details_count: detailsCount, all_details_open: allDetailsOpen, copy_buttons: copies.length,
      copy_fallback_selection_chars: fallbackSelection.length,
      copy_fallback_instruction: /вручную|Ctrl|Cmd|⌘|выделен|скопирован/i.test(fallbackText),
      print_called: printCalled, print_body_chars: printBody.length, mobile_overflow: mobileOverflow,
      external_requests: network, js_errors: errors });
    await page.close();
  }
  await browser.close();
  console.log(JSON.stringify(results, null, 2));
  if (results.some(r => r.js_errors.length || r.external_requests.length || r.mobile_overflow || !r.print_called || !r.copy_buttons || (!r.copy_fallback_selection_chars && !r.copy_fallback_instruction))) process.exitCode = 1;
}
main().catch(error => { console.error(error); process.exitCode = 1; });
