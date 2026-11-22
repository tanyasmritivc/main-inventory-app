import {shareTitle, shareDescription, socialText} from '@/lib/marketing-social';
import type {Metadata} from 'next';
import {HomePage} from '@/components/marketing-dark/home';
export const metadata: Metadata = {
 title: {absolute:shareTitle},
 description:shareDescription,
 alternates:{canonical:'/'},
 ...socialText(shareTitle, shareDescription, '/', false)
};
export default function Page(){return <HomePage/>;}
