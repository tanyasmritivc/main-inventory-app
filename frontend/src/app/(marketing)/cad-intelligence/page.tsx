import {socialText} from '@/lib/marketing-social';
import {CadPublicPage} from '@/components/marketing-dark/cad-public';
export const metadata={
  ...socialText("CAD Intelligence | FindEZ AI", "Compare a Fusion assembly parts list with your FindEZ inventory. See covered parts, shortages, missing components and matches that need review.", "/cad-intelligence"),
  alternates: {canonical: "/cad-intelligence"},
title:{absolute:'CAD Intelligence | FindEZ AI'},description:'Compare a Fusion assembly parts list with your FindEZ inventory. See covered parts, shortages, missing components and matches that need review.'};
export default function Page(){return <CadPublicPage/>;}
