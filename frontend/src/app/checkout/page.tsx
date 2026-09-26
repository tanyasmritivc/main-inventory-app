import { CheckoutClient } from "@/components/site/checkout-client";
import { ProtectedAppPage } from "@/components/site/protected-app-page";

export default function CheckoutPage() {
  return <ProtectedAppPage returnTo="/checkout"><CheckoutClient /></ProtectedAppPage>;
}
