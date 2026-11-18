const {chromium}=require('playwright');
const fs=require('fs');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
 const answer='**Your gears**\n\nFound 3 matching records across your organization.\n\n| Part | Quantity | Space / location |\n| --- | ---: | --- |\n| Gear 30T M0.8 | 8 | Workshop · Drawer B |\n| Servo Gear 40T | 5 | Storage · Bin 3 |\n| Miter Gear 24T | 3 | Storage · Shelf 2 |';
 const receipts=[];
 for(const width of [1440,390])for(const theme of ['light','dark']){
  const context=await browser.newContext({viewport:{width,height:900},reducedMotion:'reduce'});
  const page=await context.newPage();
  const requests=[];const errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  await page.route('**/*',async route=>{
   const u=new URL(route.request().url());
   if(u.hostname==='localhost'||u.hostname==='127.0.0.1')return route.continue();
   if(u.pathname.endsWith('/ai_command')){
    const body=route.request().postDataJSON();requests.push({path:u.pathname,body});
    const events=[{type:'delta',delta:'Abandoned duplicate'}, {type:'reset'}, {type:'delta',delta:answer},{type:'done',assistant_message:answer,conversation_id:'fixture-conversation',message_id:'fixture-receipt'}];
    return route.fulfill({status:200,contentType:'text/event-stream',headers:{'Access-Control-Allow-Origin':'*'},body:events.map(e=>'data: '+JSON.stringify(e)+'\n\n').join('')});
   }
   if(u.pathname.endsWith('/conversations'))return route.fulfill({json:[],headers:{'Access-Control-Allow-Origin':'*'}});
   return route.fulfill({json:{},headers:{'Access-Control-Allow-Origin':'*'}});
  });
  await page.goto('http://localhost:3117/chat-recovery-fixture',{waitUntil:'networkidle',timeout:90000});
  await page.evaluate(theme=>{document.documentElement.dataset.appTheme=theme;document.documentElement.classList.toggle('dark',theme==='dark');},theme);
  if(await page.getByRole('button',{name:'Got it',exact:true}).count())await page.getByRole('button',{name:'Got it',exact:true}).click();
  const dialog=page.locator('.app-frame');
  await page.getByRole('textbox').fill('Were are my gears');
  await page.getByRole('textbox').press('Enter');
  await page.getByRole('table').waitFor({timeout:20000});
  await page.getByText('Your gears',{exact:true}).waitFor();
  if(await page.getByText('Abandoned duplicate').count())throw Error('Duplicate survived reset');
  if(await page.getByText('This answer was interrupted.',{exact:false}).count())throw Error('Unexpected interruption');
  if(requests.length!==1||!!requests[0].body.context_inventory_id||!requests[0].path.includes('/worlds/20000000-0000-0000-0000-000000000001/'))throw Error('Scope mismatch');
  const metrics=await dialog.evaluate(el=>({width:el.getBoundingClientRect().width,right:el.getBoundingClientRect().right,bold:el.querySelector('.ask-markdown strong')?.textContent,tables:el.querySelectorAll('table').length}));
  if(metrics.right>width||metrics.bold!=='Your gears'||metrics.tables!==1)throw Error(JSON.stringify(metrics));
  await page.screenshot({path:`/tmp/findez-cad-render/main-${width}-${theme}.png`});
  if(errors.some(e=>/hydration|cannot be a child|cannot contain/i.test(e)))throw Error(errors.join('\n'));
  receipts.push({viewport:width,theme,...metrics,mainChatScope:'passed',tableConsole:'passed'});await context.close();
 }
 await browser.close();fs.writeFileSync('/tmp/findez-cad-render/main-results.json',JSON.stringify(receipts,null,2));console.log(JSON.stringify(receipts));
})().catch(e=>{console.error(e);process.exit(1)});
