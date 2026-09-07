import { LabelStudioClient } from "@/components/site/label-studio-client";
import { ProtectedAppPage } from "@/components/site/protected-app-page";
export default function LabelsPage() { return <ProtectedAppPage returnTo="/labels"><LabelStudioClient /></ProtectedAppPage>; }
