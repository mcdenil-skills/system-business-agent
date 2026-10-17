// Development-only browser checks. Installed skill has no runtime dependency.
// Catches broken rendering, misleading links, hidden content, unsafe data and overflow.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const { pathToFileURL } = require('node:url');

const root = path.resolve(__dirname, '..');
const templatePath = path.join(root, 'skills/product-line/assets/product-line-template.html');
const fixturePath = path.join(__dirname, 'evals/product-line/files/demo-product-line-data.json');
const clone = value => JSON.parse(JSON.stringify(value));

async function main() {
  assert.ok(fs.existsSync(templatePath), 'Missing product-line HTML template: implement the autonomous result page');
  const { chromium } = require(process.env.PRODUCT_LINE_PLAYWRIGHT || 'playwright');
  const template = fs.readFileSync(templatePath, 'utf8');
  const demo = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));
  const workspace = process.env.PRODUCT_LINE_HTML_WORKSPACE || fs.mkdtempSync(path.join(os.tmpdir(), 'product-line-html-'));
  fs.mkdirSync(workspace, { recursive: true });
  const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  const browser = await chromium.launch({ headless: true, ...(fs.existsSync(chrome) ? { executablePath: chrome } : {}) });
  const results = [];

  function inject(data, raw = false) {
    // The same documented insertion boundary used by an authoring agent.
    const payload = raw ? data : JSON.stringify(data).replace(/</g, '\\u003c');
    const replaced = template.replace(/(<script\b[^>]*\bid=["']product-line-data["'][^>]*>)[\s\S]*?(<\/script>)/i, (_, start, end) => start + payload + end);
    assert.notEqual(replaced, template, 'Template must provide script#product-line-data JSON insertion point');
    return replaced;
  }

  async function open(name, content, options = {}) {
    const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
    const errors = [], network = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('request', request => { if (/^https?:/.test(request.url())) network.push(request.url()); });
    await page.route(/^https?:/, route => route.abort());
    await page.addInitScript(({ copy }) => {
      window.print = () => { window.__printCalls = (window.__printCalls || 0) + 1; };
      if (copy) Object.defineProperty(navigator, 'clipboard', { configurable: true, value: { writeText: async text => { window.__copiedText = text; } } });
      else {
        Object.defineProperty(navigator, 'clipboard', { configurable: true, value: undefined });
        // Native command can fail in browser policies: manual fallback must remain usable.
        document.execCommand = () => false;
      }
    }, { copy: options.copy === true });
    const file = path.join(workspace, name + '.html');
    fs.writeFileSync(file, content);
    await page.goto(pathToFileURL(file).href);
    await page.waitForLoadState('load');
    return { page, errors, network, name };
  }

  async function clean(run) {
    assert.deepEqual(run.errors, [], `${run.name}: uncaught JavaScript errors`);
    assert.deepEqual(run.network, [], `${run.name}: page attempted external requests`);
    await run.page.close();
  }

  try {
    const normal = await open('demo', inject(demo), { copy: true });
    const p = normal.page;
    assert.match(await p.title(), /Продуктовая линейка/);
    const nearestAction = p.locator('.next');
    assert.equal(await nearestAction.count(), 1, 'Present one clear nearest action');
    assert.equal(await nearestAction.evaluate(el => { const r = el.getBoundingClientRect(); return r.top >= 0 && r.bottom <= innerHeight; }), true, 'Nearest action must be readable on the first desktop screen');
    await p.screenshot({ path: path.join(workspace, 'viewport-1280x900.png'), fullPage: false });
    await p.setViewportSize({ width: 390, height: 844 });
    assert.equal(await nearestAction.evaluate(el => { const r = el.getBoundingClientRect(); return r.top >= 0 && r.bottom <= innerHeight; }), true, 'Nearest action must be readable on the first mobile screen');
    await p.screenshot({ path: path.join(workspace, 'viewport-390x844.png'), fullPage: false });
    await p.setViewportSize({ width: 1280, height: 900 });
    assert.equal(await p.getByRole('alert').count(), 0, 'Valid data must render without an error');
    assert.equal(await p.locator('[data-view="map"]:visible [data-offer-id]').count(), 6);
    await p.getByRole('button', { name: 'Таблица', exact: true }).click();
    assert.equal(await p.locator('[data-view="table"]').isVisible(), true);
    const rows = p.locator('[data-view="table"] tbody tr[data-offer-id]');
    assert.equal(await rows.count(), 6);
    assert.match(await rows.filter({ hasText: 'Настройка базы клиентов' }).innerText(), /60 000 ₽/);
    await p.getByRole('button', { name: 'Карта', exact: true }).click();
    for (const [kind, label, target] of [['upgrade', /более полный|апселл/i, 'Внедрение с сопровождением'], ['complement', /дополн|кросс/i, 'Отчёт по источникам'], ['alternative', /альтернатив|даун/i, 'Самостоятельная настройка с разбором']]) {
      const link = p.locator(`[data-view="map"] [data-transition-kind="${kind}"]`);
      assert.equal(await link.count(), 1, `Expected one ${kind} branch`);
      const visible = await link.innerText();
      assert.match(visible, label, `${kind} needs a human-readable semantic label`);
      assert.ok(visible.includes(target), `${kind} points to the wrong offer`);
      assert.ok(visible.includes('Настройка базы клиентов'), `${kind} must identify its source`);
    }
    const detail = p.locator('[data-view="map"] [data-offer-id="core"] details');
    assert.equal(await detail.count(), 1, 'Core card must expose details');
    assert.equal(await detail.evaluate(el => el.open), false);
    await detail.locator('summary').click();
    assert.equal(await detail.evaluate(el => el.open), true);
    assert.match(await detail.innerText(), /Участие и усилия клиента/, 'effort describes the customer contribution, not executor workload');
    assert.match(await detail.innerText(), /Один час клиента: предоставить данные и согласовать результат/);
    assert.match(await detail.innerText(), /12 часов исполнителя/);
    const copy = p.getByRole('button', { name: /Копировать/ }).first();
    await copy.click();
    assert.match(await p.evaluate(() => window.__copiedText || ''), /Настройка базы клиентов/);
    assert.match(await p.evaluate(() => window.__copiedText || ''), /Назначить один разговор/);
    for (const width of [1280, 390, 320]) {
      await p.setViewportSize({ width, height: 900 });
      for (const view of ['Карта', 'Таблица']) {
        await p.getByRole('button', { name: view, exact: true }).click();
        assert.equal(await p.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2), false, `${view}: page overflows at ${width}px`);
      }
      await p.getByRole('button', { name: 'Карта', exact: true }).click();
      await p.screenshot({ path: path.join(workspace, `demo-${width}.png`), fullPage: true });
    }
    await p.getByRole('button', { name: 'Таблица', exact: true }).click();
    await p.locator('details').evaluateAll(items => items.forEach(el => { el.open = false; }));
    await p.getByRole('button', { name: 'Печать / PDF', exact: true }).click();
    assert.equal(await p.evaluate(() => window.__printCalls), 1);
    await p.emulateMedia({ media: 'print' });
    assert.match(await p.locator('body').innerText(), /12 часов исполнителя/, 'Print must include details even if collapsed');
    assert.match(await p.locator('body').innerText(), /Назначить один разговор/);
    assert.equal(await p.getByRole('button', { name: 'Печать / PDF', exact: true }).isVisible(), false);
    await p.pdf({ path: path.join(workspace, 'demo-print.pdf'), format: 'A4', printBackground: true });
    assert.ok(fs.statSync(path.join(workspace, 'demo-print.pdf')).size > 1000);
    results.push('map/table, semantic branches, details, clipboard, widths 1280/390/320, print/PDF');
    await clean(normal);

    const fallback = await open('copy-fallback', inject(demo));
    await fallback.page.getByRole('button', { name: /Копировать/ }).first().click();
    const manual = fallback.page.getByRole('textbox');
    assert.equal(await manual.count(), 1, 'Blocked clipboard must expose a manual copy textbox');
    assert.equal(await manual.isVisible(), true);
    assert.match(await manual.inputValue(), /Настройка базы клиентов/);
    assert.equal(await manual.evaluate(el => el.selectionEnd - el.selectionStart > 0), true, 'Fallback text should be selected');
    assert.match(await fallback.page.locator('body').innerText(), /Ctrl|Cmd|⌘/);
    results.push('manual clipboard fallback');
    await clean(fallback);

    const coreOnly = clone(demo);
    coreOnly.offers = coreOnly.offers.filter(o => o.id === 'core');
    coreOnly.transitions = [];
    coreOnly.entryBrief = null;
    const minimal = await open('core-only', inject(coreOnly));
    assert.equal(await minimal.page.locator('[data-view="map"] [data-offer-id]').count(), 1, 'No fictitious cards for deferred roles');
    assert.equal(await minimal.page.locator('[data-transition-kind]').count(), 0);
    assert.equal(await minimal.page.getByRole('alert').count(), 0, 'Brief is optional for direct entry');
    assert.equal(await minimal.page.getByText('Проверка потерянных заявок', { exact: true }).count(), 0);
    assert.match(await minimal.page.locator('body').innerText(), /Сначала проверяем основной продукт напрямую/);
    results.push('core-only, null brief, role decisions without fictional offers');
    await clean(minimal);

    const reusedTripwire = clone(demo);
    reusedTripwire.offers = reusedTripwire.offers.filter(o => o.role !== 'downsell');
    reusedTripwire.transitions = [{ from: 'core', to: 'review', kind: 'alternative',
      trigger: 'Клиент отказался от внедрения: нужна только помощь с планом, внедрит сам.',
      reason: 'Существующий разбор решает меньшую задачу. Используем его повторно, не создавая отдельный даун-селл.',
      action: 'Уточнить готовность клиента внедрить план самостоятельно и предложить разбор.' }];
    reusedTripwire.roleDecisions.find(r => r.role === 'downsell').reason = 'При подходящей причине отказа используем существующий трипваер; отдельная карточка не нужна.';
    const reused = await open('reused-tripwire-alternative', inject(reusedTripwire));
    assert.equal(await reused.page.getByRole('alert').count(), 0, 'Existing tripwire can serve as a lower-scope alternative without a duplicate offer');
    assert.equal(await reused.page.locator('[data-view="map"] [data-offer-id]').count(), 5);
    assert.equal(await reused.page.locator('[data-view="map"] [data-offer-id="self"]').count(), 0);
    assert.equal(await reused.page.locator('[data-view="map"] [data-offer-id="review"]').count(), 1);
    const reusedLink = reused.page.locator('[data-view="map"] [data-transition-kind="alternative"]');
    assert.equal(await reusedLink.count(), 1);
    assert.match(await reusedLink.innerText(), /Настройка базы клиентов → Разбор одного источника заявок/);
    assert.match(await reusedLink.innerText(), /Клиент отказался от внедрения/);
    await clean(reused);
    results.push('reuse existing tripwire as contextual alternative without duplicate offer');

    const empty = await open('placeholder', template);
    assert.equal(await empty.page.locator('[data-offer-id]').count(), 0);
    assert.equal(await empty.page.getByRole('alert').count(), 0, 'Unfilled template is a placeholder, not corrupted data');
    assert.match(await empty.page.locator('body').innerText(), /шаблон|данные.*не заполнены/i);
    await clean(empty);
    results.push('null placeholder');

    const invalids = [
      ['malformed-json', '{"version":', true],
      ['bad-source', d => { d.transitions[0].from = 'missing'; }],
      ['bad-target', d => { d.transitions[0].to = 'missing'; }],
      ['duplicate-id', d => { d.offers[1].id = 'check'; }],
      ['invalid-role', d => { d.offers[0].role = 'discount'; }],
      ['translated-decision-role', d => { d.roleDecisions[0].role = 'Основной продукт'; }],
      ['bad-kind', d => { d.transitions[0].kind = 'linear-upsell'; }],
      ['bad-brief-link', d => { d.entryBrief.offerId = 'missing'; }],
      ['wrong-result-type', d => { d.offers[0].result = null; }],
      ['wrong-upgrade-target', d => { d.transitions[2].to = 'extra'; }],
      ['wrong-complement-target', d => { d.transitions[3].to = 'self'; }],
      ['wrong-alternative-target', d => { d.transitions[4].to = 'plus'; }],
      ['bad-version', d => { d.version = 3; }]
    ];
    for (const [name, mutate, raw] of invalids) {
      const data = clone(demo);
      if (!raw) mutate(data);
      const bad = await open(name, inject(raw ? mutate : data, raw));
      assert.equal(await bad.page.getByRole('alert').count(), 1, `${name}: show understandable data error`);
      assert.match(await bad.page.getByRole('alert').innerText(), /данн|JSON|ошиб/i);
      assert.equal(await bad.page.locator('[data-offer-id]').count(), 0, `${name}: do not show partial misleading map`);
      await clean(bad);
    }
    results.push('malformed JSON, broken references, duplicate IDs, invalid roles/kinds/version');

    const hostileData = clone(demo);
    const hostile = '</script><img src="https://example.invalid/exfil" onerror="window.__pwned=true"><script>window.__pwned=true</script>';
    hostileData.offers[2].name = hostile;
    hostileData.meta.title = hostile;
    hostileData.entryBrief.sample = hostile;
    hostileData.unknowns.push(hostile, 'ОченьДлинныйНеразрывныйТекст'.repeat(50));
    const safe = await open('hostile-text', inject(hostileData));
    assert.equal(await safe.page.evaluate(() => window.__pwned === true), false);
    assert.equal(await safe.page.locator('img').count(), 0, 'Data must not create HTML elements');
    assert.ok((await safe.page.locator('body').innerText()).includes(hostile));
    await safe.page.setViewportSize({ width: 320, height: 900 });
    assert.equal(await safe.page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2), false, 'Long hostile text must wrap');
    await safe.page.screenshot({ path: path.join(workspace, 'hostile-320.png'), fullPage: true });
    await clean(safe);
    results.push('hostile text inert, long tokens wrap, no external requests');
    console.log(JSON.stringify({ status: 'PASS', workspace, checks: results }, null, 2));
  } finally { await browser.close(); }
}
main().catch(error => { console.error(`FAIL: ${error.message}`); process.exitCode = 1; });
