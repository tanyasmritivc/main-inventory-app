const {chromium}=require('playwright');const fs=require('fs');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});const receipts=[];
 const answer='**Your gears**\n\n| Part | Quantity | Space |\n| --- | ---: | --- |\n'+Array.from({length:24},(_,i)=>`| Gear ${i+1} | 8 | Workshop |`).join('\n');
 for(const [width,height] of [[1920,960],[1280,720],[390,844],[375,500]])for(const theme of ['dark','light'])for(const main of [false,true]){
 const ctx=await browser.newContext({viewport:{width,height}});const page=await ctx.newPage();let sent=0;const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.route('**/*',async route=>{const u=new URL(route.request().url());if(['localhost','127.0.0.1'].includes(u.hostname))return route.continue();
 if(u.pathname.endsWith('/ai_command')){sent++;return route.fulfill({status:200,contentType:'text/event-stream',headers:{'Access-Control-Allow-Origin':'*'},body:[{type:'delta',delta:answer},{type:'done',assistant_message:answer,conversation_id:'fixture',message_id:'answer'}].map(e=>'data: '+JSON.stringify(e)+'\n\n').join('')});}
 return route.fulfill({json:u.pathname.endsWith('/conversations')?[]:{},headers:{'Access-Control-Allow-Origin':'*'}});});
 await page.goto('http://localhost:3117/ask-layout-fixture'+(main?'?main=1':''),{waitUntil:'networkidle',timeout:90000});
 await page.evaluate(t=>{document.documentElement.dataset.appTheme=t;document.documentElement.classList.toggle('dark',t==='dark');},theme);
 if(await page.getByRole('button',{name:'Got it',exact:true}).count())await page.getByRole('button',{name:'Got it',exact:true}).click();
 if(!main)await page.getByRole('button',{name:'Ask FindEZ about Fixture Robotics'}).click();
 await page.waitForTimeout(1100);
 async function measure(state){const m=await page.evaluate(({main})=>{const host=document.querySelector(main?'.ask-workspace':'[role=dialog]');const box=host.querySelector('.ask-composer-box'),input=host.querySelector('textarea'),send=host.querySelector('button[type=submit]'),title=host.querySelector('h1');const r=e=>{const b=e.getBoundingClientRect();return {left:b.left,right:b.right,top:b.top,bottom:b.bottom,width:b.width,height:b.height}};return {host:r(host),box:r(box),input:r(input),send:r(send),title:r(title),color:getComputedStyle(title).color,shiny:!!title.querySelector('.shiny-text'),scroll:host.querySelector('.ask-thread').scrollHeight,client:host.querySelector('.ask-thread').clientHeight};},{main});
 for(const k of ['box','input','send'])if(m[k].left<0||m[k].right>width+1||m[k].bottom>height+1||m[k].top<0||m[k].height<1||(!main&&m[k].bottom>m.host.bottom))throw Error(JSON.stringify({width,height,theme,main,state,k,m}));
 if(main&&m.box.width>601)throw Error('Composer too wide');if(m.shiny)throw Error('Shiny caption');
 if(state==='empty'&&theme==='dark'&&m.color!=='rgb(244, 244, 245)'&&m.color!=='rgb(243, 243, 242)') {const rgb=m.color.match(/\d+/g).map(Number);if(rgb.some(n=>n<230))throw Error('Caption not white '+m.color);}
 return m;}
 if(errors.length)throw Error(errors.join('\n'));const empty=await measure('empty');await page.screenshot({path:`/tmp/findez-cad-render/layout-${main?'main':'panel'}-${width}-${theme}-empty.png`});
 await page.getByRole('textbox',{name:'Your question'}).fill('Where are my gears?');await page.getByRole('textbox',{name:'Your question'}).press('Enter');await page.getByRole('table').waitFor();await page.waitForTimeout(700);const full=await measure('answered');if(sent!==1)throw Error('Request mismatch');
 if(!main){await page.evaluate(()=>window.scrollTo(0,700));await measure('page scrolled');}
 await page.screenshot({path:`/tmp/findez-cad-render/layout-${main?'main':'panel'}-${width}-${theme}-full.png`});receipts.push({width,height,theme,main,empty,full});await ctx.close();console.log('PASS',width,height,theme,main?'main':'panel');
 }
 fs.writeFileSync('/tmp/findez-cad-render/layout-results.json',JSON.stringify(receipts,null,2));await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
