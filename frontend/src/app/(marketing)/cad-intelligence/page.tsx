import {socialText} from '@/lib/marketing-social';
import {CadPublicPage} from '@/components/marketing-dark/cad-public';

const title = 'CAD Intelligence | FindEZ AI';
const description = 'Connect Autodesk Fusion to your physical inventory. Find parts, generate custom STEP models, compare assembly BOMs, and plan purchases for confirmed shortages.';
const path = '/cad-intelligence';

export const metadata = {
  title: {absolute: title},
  description,
  alternates: {canonical: path},
  ...socialText(title, description, path),
};

export default function Page() {
  return <CadPublicPage/>;
}
