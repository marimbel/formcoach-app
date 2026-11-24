const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 2200, height: 1000 }, deviceScaleFactor: 2 });
  await p.goto('file://' + process.cwd() + '/screens.html');
  await p.waitForTimeout(300);
  await (await p.$('#banner')).screenshot({ path: 'banner.png' });
  for (const id of ['home', 'live', 'trainer', 'summary', 'progress'])
    await (await p.$('#c-' + id + ' .phone')).screenshot({ path: id + '.png' });
  await b.close();
})();
