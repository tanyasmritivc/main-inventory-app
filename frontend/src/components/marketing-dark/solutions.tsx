import './home.css';
import './solutions.css';
import {BackgroundMarkup,HeaderMarkup,FooterMarkup} from './home-content';
import {HeaderMotion,ScrollMotion,BackgroundMotion} from './home-motion';
import {SolutionsHero,AudienceRows,InventoryMorph,SolutionsEnd} from './solutions-content';
import {InventoryMapMotion,AudienceMotion,InventoryMorphMotion} from './solutions-motion';
export function SolutionsPage(){return <div className="landing-home solutions-page" id="top">
<BackgroundMarkup/><HeaderMarkup cadHref="/#cad" currentPage="solutions"/>
<main id="main"><SolutionsHero/><AudienceRows/><InventoryMorph/><SolutionsEnd/></main>
<FooterMarkup cadHref="/#cad"/>
<HeaderMotion/><ScrollMotion/><BackgroundMotion solutions/><InventoryMapMotion/><AudienceMotion/><InventoryMorphMotion/>
</div>;}
