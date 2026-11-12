import './home.css';
import './solutions.css';
import {HeaderMarkup,FooterMarkup} from './home-content';
import {HeaderMotion,ScrollMotion} from './home-motion';
import {SolutionsHero,AudienceCards,InventoryMorph,SolutionsEnd} from './solutions-content';
import {InventoryMapMotion,InventoryMorphMotion} from './solutions-motion';
export function SolutionsPage(){return <div className="landing-home solutions-page" id="top">
<HeaderMarkup cadHref="/#cad" currentPage="solutions"/>
<main id="main"><SolutionsHero/><AudienceCards/><InventoryMorph/><SolutionsEnd/></main>
<FooterMarkup cadHref="/#cad"/>
<HeaderMotion/><ScrollMotion/><InventoryMapMotion/><InventoryMorphMotion/>
</div>;}
