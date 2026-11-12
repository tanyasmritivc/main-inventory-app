import './cad-public.css';
import {HeaderMarkup,FooterMarkup} from './public-chrome';
import {ScrollMotion} from './home-motion';
import {CadHero,CadComparison,CadResults,CadPipeline,CadFiles,CadEvidence,CadPrivacy,CadLimitations,CadStart} from './cad-public-content';
import {CadBackgroundMotion,CadComparisonMotion,CadResultsMotion,CadPipelineMotion,CadFilesMotion,CadEvidenceMotion,CadPrivacyMotion,CadFolderMotion} from './cad-public-motion';
export function CadPublicPage(){return <div className="cad-public-page" id="top">
<div className="cad-bg-wrap"><canvas id="x-bg" aria-hidden="true"/></div><HeaderMarkup currentPage="cad-intelligence"/>
<main id="main"><CadHero/><CadComparison/><CadResults/><CadPipeline/><CadFiles/><CadEvidence/><CadPrivacy/><CadLimitations/><CadStart/></main>
<FooterMarkup/><ScrollMotion/><CadBackgroundMotion/><CadComparisonMotion/><CadResultsMotion/><CadPipelineMotion/><CadFilesMotion/><CadEvidenceMotion/><CadPrivacyMotion/><CadFolderMotion/>
</div>;}
