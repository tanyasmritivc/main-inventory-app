import { ScanCenterClient } from "@/components/site/scan-center-client";
import { ProtectedAppPage } from "@/components/site/protected-app-page";
export const metadata = { title: "Capture" };

export default function ScanPage() { return <ProtectedAppPage returnTo="/scan"><ScanCenterClient /></ProtectedAppPage>; }
