import './home.css';
import {BackgroundMarkup,HeaderMarkup,HeroMarkup,PinnedMarkup,ExamplesMarkup,FoundersMarkup,FooterMarkup} from './home-content';
import {HeaderMotion,TourMotion,ScrollMotion,BackgroundMotion,PinnedMotion,FoundersMotion} from './home-motion';
import {CadIntelligenceSection} from './cad-intelligence-section';
export function HomePage(){return <div className="landing-home" id="top">
  <BackgroundMarkup/><HeaderMarkup/>
  <main id="main"><HeroMarkup/><CadIntelligenceSection/><PinnedMarkup/><ExamplesMarkup/><FoundersMarkup/></main>
  <FooterMarkup/>
  <HeaderMotion/><TourMotion/><ScrollMotion/><BackgroundMotion/><PinnedMotion/><FoundersMotion/>
</div>;}
