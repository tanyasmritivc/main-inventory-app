import { CheckoutClient } from "@/components/site/checkout-client";
import { ProtectedAppPage } from "@/components/site/protected-app-page";

export const metadata = { title: "Lent items" };

export default function CheckoutPage() {
  return <ProtectedAppPage returnTo="/checkout"><CheckoutClient /></ProtectedAppPage>;
}
