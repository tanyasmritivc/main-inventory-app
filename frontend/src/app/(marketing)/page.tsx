import type {Metadata} from 'next';
import {HomePage} from '@/components/marketing-dark/home';
export const metadata: Metadata = {
 title: {absolute:'FindEZ AI | The AI inventory for people who build things'},
 description:'Snap a shelf. Ask where anything is. Get the exact bin.',
 alternates:{canonical:'/'},
 openGraph:{title:'FindEZ AI | The AI inventory for people who build things',url:'/'}
};
export default function Page(){return <HomePage/>;}
