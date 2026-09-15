import { redirect } from "next/navigation";

export default function UpgradeSuccessPage() {
  redirect("/inventory");
}
