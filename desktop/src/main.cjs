'use strict';
const { app, BrowserWindow, Menu, dialog, shell, session } = require('electron');
const path = require('node:path');
const {APP_ORIGIN, trusted, external, oauth, AuthHandoff, permissionAllowed} = require('./policy.cjs');
const handoff=new AuthHandoff();
let window, initialLink=process.argv.find(arg=>arg.startsWith('findez-desktop:')), quitting=false;
const offline=path.join(__dirname,'offline.html');
const granted=new Set();
if (!app.isPackaged && process.env.FINDEZ_DESKTOP_TEST_PROFILE) app.setPath('userData',process.env.FINDEZ_DESKTOP_TEST_PROFILE);
app.setName('FindEZ');
app.setAppUserModelId('ai.findez.desktop');
if (!app.requestSingleInstanceLock()) { app.quit(); }
else {
  app.on('second-instance',(_event,args)=>{const link=args.find(a=>a.startsWith('findez-desktop:'));if(link)void acceptLink(link);focus();});
  app.on('open-url',(event,link)=>{event.preventDefault();if(app.isReady())void acceptLink(link);else initialLink=link;});
  app.whenReady().then(()=>{if(app.isPackaged)app.setAsDefaultProtocolClient('findez-desktop');createWindow();});
}
function focus(){if(!window)return;if(window.isMinimized())window.restore();window.show();window.focus();}
async function showError(message){if(window&&!window.isDestroyed())await dialog.showMessageBox(window,{type:'info',title:'FindEZ',message,buttons:['OK']});}
async function acceptLink(link){
  try{const target=handoff.finish(link);if(!window||window.isDestroyed())createWindow();await window.loadURL(target);focus();}
  catch(error){await showError(error.message);}
}
async function openOutside(value){if(external(value))await shell.openExternal(value);}
async function startBrowserSignIn(value){try{await shell.openExternal(handoff.begin(value));}catch(error){await showError(error.message);}}
function route(event,value){
  if(trusted(value))return;
  event.preventDefault();
  if(oauth(value))void startBrowserSignIn(value);else if(external(value))void openOutside(value);
}
function createWindow(){
  if(window&&!window.isDestroyed()){focus();return;}
  const ses=session.fromPartition('persist:findez');
  ses.setPermissionCheckHandler((_contents,permission,origin)=>permissionAllowed(origin,permission)&&granted.has(permission));
  ses.setPermissionRequestHandler(async(contents,permission,callback,details)=>{
    if(contents!==window?.webContents || !permissionAllowed(details.requestingUrl||contents.getURL(),permission)){callback(false);return;}
    const label=permission==='media' ? 'camera or microphone' : 'notifications';
    const {response}=await dialog.showMessageBox(window,{type:'question',title:'FindEZ permission',message:`Allow FindEZ to use ${label}?`,detail:'Only allow this when you are using a feature that needs it.',buttons:['Not now','Allow'],defaultId:0,cancelId:0});
    if(response===1)granted.add(permission);callback(response===1);
  });
  ses.removeAllListeners('will-download');
  ses.on('will-download',(event,item,contents)=>{
    if(contents!==window?.webContents || !(trusted(item.getURL()) || item.getURL().startsWith('blob:'+APP_ORIGIN+'/') || external(item.getURL()))){event.preventDefault();return;}
    item.setSaveDialogOptions({title:'Save from FindEZ',defaultPath:path.join(app.getPath('downloads'),path.basename(item.getFilename()))});
    item.once('done',(_e,state)=>{if(state==='interrupted')void showError('The download was interrupted. Please try again.');});
  });
  window=new BrowserWindow({width:1280,height:860,minWidth:1000,minHeight:640,show:false,title:'FindEZ',backgroundColor:'#111112',icon:path.join(__dirname,'../build/icon.png'),autoHideMenuBar:process.platform!=='darwin',webPreferences:{partition:'persist:findez',nodeIntegration:false,nodeIntegrationInWorker:false,nodeIntegrationInSubFrames:false,contextIsolation:true,sandbox:true,webSecurity:true,allowRunningInsecureContent:false,webviewTag:false,spellcheck:true}});
  window.once('ready-to-show',()=>window.show());window.on('closed',()=>{window=null;});
  const contents=window.webContents;
  contents.on('will-navigate',route);contents.on('will-redirect',route);
  // The signed-in app keeps the web desktop layout. Onboarding remains responsive.
  const applyWindowLayout=()=>{
    if(window?.isDestroyed() || !window)return;
    let onboarding=false;
    try{const u=new URL(contents.getURL());onboarding=trusted(u.href)&&(u.pathname==='/onboarding'||u.pathname.startsWith('/onboarding/'));}catch{}
    const minWidth=onboarding?720:1000, minHeight=onboarding?560:640;
    window.setMinimumSize(minWidth,minHeight);
    const [width,height]=window.getSize();
    if(width<minWidth||height<minHeight)window.setSize(Math.max(width,minWidth),Math.max(height,minHeight));
  };
  contents.on('did-navigate',applyWindowLayout);
  contents.on('did-navigate-in-page',applyWindowLayout);
  contents.on('will-attach-webview',event=>event.preventDefault());
  contents.setWindowOpenHandler(({url})=>{if(oauth(url))void startBrowserSignIn(url);else if(trusted(url))void contents.loadURL(url);else void openOutside(url);return {action:'deny'};});
  contents.on('did-fail-load',(_event,code,_description,failedUrl,isMainFrame)=>{if(isMainFrame && code!==-3 && trusted(failedUrl))void window?.loadFile(offline);});
  contents.on('render-process-gone',()=>{if(!quitting)void window?.loadFile(offline);});
  makeMenu();void window.loadURL(APP_ORIGIN+'/worlds').catch(()=>{});
  if(initialLink){const link=initialLink;initialLink=null;void acceptLink(link);}
}
function navigate(route){if(!window||window.isDestroyed())createWindow();void window.loadURL(APP_ORIGIN+route).catch(()=>{});focus();}
function makeMenu(){
  const items=[
    ...(process.platform==='darwin'?[{label:'FindEZ',submenu:[{role:'about'},{type:'separator'},{role:'hide'},{role:'hideOthers'},{role:'unhide'},{type:'separator'},{role:'quit'}]}]:[]),
    {label:'File',submenu:[{label:'Open FindEZ',accelerator:'CmdOrCtrl+Home',click:()=>navigate('/worlds')},{label:'CAD Intelligence',accelerator:'CmdOrCtrl+Shift+C',click:()=>navigate('/cad')},{label:'Settings',accelerator:'CmdOrCtrl+,',click:()=>navigate('/settings')},{type:'separator'},{label:'Show Downloads',click:()=>void shell.openPath(app.getPath('downloads'))},{type:'separator'},process.platform==='darwin'?{role:'close'}:{role:'quit'}]},
    {role:'editMenu'},
    {label:'View',submenu:[{role:'reload'},{role:'forceReload'},{type:'separator'},{role:'resetZoom'},{role:'zoomIn'},{role:'zoomOut'},{type:'separator'},{role:'togglefullscreen'},{label:'Back',accelerator:'Alt+Left',click:()=>{if(window?.webContents.navigationHistory.canGoBack())window.webContents.navigationHistory.goBack();}},{label:'Forward',accelerator:'Alt+Right',click:()=>{if(window?.webContents.navigationHistory.canGoForward())window.webContents.navigationHistory.goForward();}}]},
    {role:'windowMenu'},
    {label:'Help',submenu:[{label:'Download updates',click:()=>void openOutside(APP_ORIGIN+'/desktop')},{label:'Open FindEZ in browser',click:()=>void openOutside(APP_ORIGIN+'/worlds')},{label:'Privacy',click:()=>void openOutside(APP_ORIGIN+'/privacy')},...(process.platform==='darwin'?[]:[{role:'about'}])]},
  ];
  app.setAboutPanelOptions({applicationName:'FindEZ',applicationVersion:app.getVersion(),copyright:'Copyright © 2026 AI Robots Inc.',website:APP_ORIGIN,iconPath:path.join(__dirname,'../build/icon.png'),credits:'Desktop preview. Internet connection required.'});
  Menu.setApplicationMenu(Menu.buildFromTemplate(items));
}
app.on('activate',()=>{if(app.isReady())createWindow();});
app.on('before-quit',()=>{quitting=true;});
app.on('window-all-closed',()=>{if(process.platform!=='darwin')app.quit();});
app.on('web-contents-created',(_event,contents)=>{contents.on('will-attach-webview',event=>event.preventDefault());});
