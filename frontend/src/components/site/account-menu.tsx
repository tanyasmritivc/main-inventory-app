"use client";
import styles from "./account-layout.module.css";
import {useMemo,useState} from 'react';
import {UserRound,LogOut,FolderKanban,Settings} from 'lucide-react';
import {DropdownMenu,DropdownMenuTrigger,DropdownMenuContent,DropdownMenuLabel,DropdownMenuItem,DropdownMenuSeparator,DropdownMenuRadioGroup,DropdownMenuRadioItem} from '@/components/ui/dropdown-menu';
import {useAppTheme,type AppThemeChoice} from './use-app-theme';
import {useInventoryRouter} from './inventory-link';
import {createSupabaseBrowserClient} from '@/lib/supabase/browser';
export function AccountMenu({name,email,initial,avatarUrl}:{name:string;email:string;initial:string;avatarUrl?:string}) {
 const {theme,setTheme}=useAppTheme(),router=useInventoryRouter();
 const client=useMemo(()=>createSupabaseBrowserClient(),[]);
 const [busy,setBusy]=useState(false),[error,setError]=useState('');
 async function signOut(){
  if(busy)return;setBusy(true);setError('');
  try{const result=await client.auth.signOut();if(result.error)throw result.error;router.replace('/');router.refresh();}
  catch{setError('Could not sign out. Please try again.');}finally{setBusy(false);}
 }
 return <div style={{position:'relative'}}><DropdownMenu modal={false}><DropdownMenuTrigger asChild>
  <button className="app-avatar" aria-label="Open profile" title="Account menu" style={avatarUrl?{backgroundImage:`url(${avatarUrl})`,backgroundSize:'cover',backgroundPosition:'center'}:undefined}>{!avatarUrl&&(initial||<UserRound size={16}/>)}</button>
 </DropdownMenuTrigger><DropdownMenuContent className={styles.menu} align="end" style={{minWidth:230,fontFamily:'var(--font-inter),Arial,sans-serif'}}>
  <DropdownMenuLabel><strong style={{display:'block',fontWeight:500}}>{name}</strong>{email&&<span style={{fontWeight:400,color:'var(--app-muted)',fontSize:12}}>{email}</span>}</DropdownMenuLabel>
  <DropdownMenuSeparator/>
  <DropdownMenuItem onSelect={()=>router.push('/settings')}><Settings size={14}/>Account settings</DropdownMenuItem>
  <DropdownMenuItem onSelect={()=>router.push('/workspaces')}><FolderKanban size={14}/>All workspaces</DropdownMenuItem>
  <DropdownMenuSeparator/><DropdownMenuLabel style={{fontWeight:400,color:'var(--app-muted)'}}>Theme</DropdownMenuLabel>
  <DropdownMenuRadioGroup value={theme} onValueChange={value=>{try{setTheme(value as AppThemeChoice);}catch{setError('Appearance could not be saved. Please try again.');}}}>
   <DropdownMenuRadioItem value="system">System</DropdownMenuRadioItem><DropdownMenuRadioItem value="dark">Dark</DropdownMenuRadioItem><DropdownMenuRadioItem value="light">Light</DropdownMenuRadioItem>
  </DropdownMenuRadioGroup>
  <DropdownMenuSeparator/><DropdownMenuItem disabled={busy} onSelect={()=>void signOut()}><LogOut size={14}/>{busy?'Signing out...':'Sign out'}</DropdownMenuItem>
 </DropdownMenuContent></DropdownMenu>{error&&<p role="alert" style={{position:'absolute',right:0,width:230,padding:12,background:'var(--app-surface)',border:'1px solid var(--app-border)',borderRadius:8,zIndex:60}}>{error}</p>}</div>;
}
