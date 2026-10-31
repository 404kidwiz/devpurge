const assert = require('node:assert/strict');
const fs = require('node:fs');
// Run against the local site with an available Puppeteer installation (see docs/launch-followups-qa.md).
const puppeteer = require('puppeteer');
const path = require('node:path');
const os = require('node:os');
const baseURL = process.env.SITE_URL || 'http://127.0.0.1:8766/';
const output = process.env.QA_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'devpurge-download-'));
fs.mkdirSync(output, {recursive:true});
(async () => {
  const browser = await puppeteer.launch({headless:true,...(process.env.CHROME_PATH ? {executablePath:process.env.CHROME_PATH} : {})});
  try {
    const page = await browser.newPage();
    const errors = []; page.on('pageerror', e => errors.push(e.message));
    await page.setViewport({width:390,height:844,isMobile:true,hasTouch:true});
    await page.emulateMediaFeatures([{name:'prefers-reduced-motion',value:'reduce'}]);
    await page.goto(baseURL,{waitUntil:'networkidle0'});
    await page.evaluate(() => document.fonts.ready);
    const expected = await page.$eval('[data-mac-download]', e => e.href);
    assert.equal(await page.$eval('[data-mac-download]',e=>e.textContent),'Download for Mac');
    assert.equal(await page.$eval('#download-terms',e=>e.textContent),'macOS 14+ · Unlimited scans · 3 free cleanups');
    // Stub only the API result, leaving the actual click handler and fallback in place.
    for(const mode of ['native','legacy','manual','throws']) {
      await page.evaluate(mode => {
        window.copiedValue = null;
        Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:async text=>{if(mode!=='native')throw Error('Permission denied'); window.copiedValue=text;}}});
        document.execCommand = () => {if(mode==='throws')throw Error('Unsupported'); if(mode==='legacy')window.copiedValue=document.querySelector('#download-link').value; return mode==='legacy';};
      }, mode);
      await page.click('[data-download-copy]');
      await page.waitForFunction(()=>!document.querySelector('[data-download-copy]').disabled);
      const state=await page.evaluate(()=>({message:document.querySelector('[data-download-status]').textContent,hidden:document.querySelector('[data-download-fallback]').hidden,value:window.copiedValue,focus:document.activeElement.id||document.activeElement.className,selected:document.querySelector('#download-link').selectionEnd-document.querySelector('#download-link').selectionStart}));
      if(mode==='native'||mode==='legacy'){assert.equal(state.value,expected);assert.equal(state.hidden,true);assert.match(state.message,/Link copied/);assert.equal(state.focus,'download-copy');}
      else{assert.equal(state.value,null);assert.equal(state.hidden,false);assert.match(state.message,/Automatic copy is unavailable/);assert.equal(state.focus,'download-link');assert.equal(state.selected,expected.length);}
      console.log('Clipboard',mode,'PASS');
    }
    await page.evaluate(()=>Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:async text=>{window.copiedValue=text;}}}));
    await page.click('[data-download-copy]');
    await page.waitForFunction(()=>document.querySelector('[data-download-fallback]').hidden);
    // Keyboard interaction: buttons, disclosure, roving tab index, and sample-only action.
    await page.focus('.palette__toggle'); await page.keyboard.press('Enter');
    assert.equal(await page.$eval('.palette__toggle',e=>e.getAttribute('aria-expanded')),'true');
    await page.keyboard.press('Tab'); await page.keyboard.press('Enter');
    await page.keyboard.press('Escape');
    assert.equal(await page.$eval('.palette__toggle',e=>document.activeElement===e),true);
    assert.equal(await page.$eval('.palette__toggle',e=>e.getAttribute('aria-expanded')),'false');
    await page.focus('#demo-tab-1');await page.keyboard.press('ArrowRight');
    assert.equal(await page.$eval('#demo-tab-2',e=>e.getAttribute('aria-selected')),'true');
    await page.keyboard.press('End');assert.equal(await page.$eval('#demo-tab-3',e=>document.activeElement===e),true);
    await page.keyboard.press('Home');assert.equal(await page.$eval('#demo-tab-1',e=>document.activeElement===e),true);
    await page.focus('.demo-guide summary');await page.keyboard.press('Enter');
    assert.equal(await page.$eval('.demo-guide',e=>e.open),true);
    await page.focus('[data-clear-all]');await page.keyboard.press('Enter');
    assert.equal(await page.$eval('[data-trash]',e=>e.getAttribute('aria-disabled')),'true');
    await page.focus('[data-select-all]');await page.keyboard.press('Enter');
    await page.focus('[data-trash]');await page.keyboard.press('Enter');
    assert.match(await page.$eval('[data-toast]',e=>e.textContent),/Demo only/);
    await page.focus('.qa summary');await page.keyboard.press('Enter');
    assert.equal(await page.$eval('.qa',e=>e.open),true);
    console.log('Keyboard palette, walkthrough, guide, sample review, FAQ PASS');
    // Native clipboard is allowed in this isolated test context; verify actual bytes.
    await browser.defaultBrowserContext().overridePermissions(new URL(baseURL).origin,['clipboard-read','clipboard-write']);
    await page.reload({waitUntil:'networkidle0'});
    await page.click('[data-download-copy]');
    await page.waitForFunction(()=>document.querySelector('[data-download-status]').textContent.startsWith('Link copied'));
    assert.equal(await page.evaluate(()=>navigator.clipboard.readText()),expected);
    console.log('Real browser clipboard bytes PASS');
    await page.evaluate(()=>scrollTo(0,0));
    for (const palette of ['zine','citrus','blacklight','ember']) {
      await page.click('.palette__toggle');await page.click(`[data-set-palette="${palette}"]`);await page.keyboard.press('Escape');
      await page.screenshot({path:path.join(output, `${palette}-390.png`)});
      const sizes=await page.evaluate(()=>{const c=document.querySelector('[data-download-copy]').getBoundingClientRect(),i=document.querySelector('[data-mac-download]').getBoundingClientRect();return {copy:[c.width,c.height],cta:[i.width,i.height],fits:document.documentElement.scrollWidth===innerWidth};});
      assert(sizes.copy.every(n=>n>=44)&&sizes.cta.every(n=>n>=44)&&sizes.fits);
    }
    const nojs=await browser.newPage();await nojs.setJavaScriptEnabled(false);await nojs.setViewport({width:320,height:568});await nojs.goto(baseURL);
    assert.equal(await nojs.$eval('[data-download-copy]',e=>e.hidden),true);
    assert.equal(await nojs.$eval('[data-mac-download]',e=>e.href),expected);
    assert.match(await nojs.$eval('.download-handoff',e=>e.textContent),/Touch and hold/);
    assert.equal(errors.length,0);
    fs.writeFileSync(path.join(output, 'checks.json'),JSON.stringify({browser:await browser.version(),clipboard:['native mocked','legacy mocked','manual fallback','throwing fallback','real browser bytes'],keyboard:['palette','walkthrough tabs','text guide','sample review','FAQ'],palettes:4,noJS:true,errors},null,2));
    console.log('All download and keyboard checks PASS');
  } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1});
