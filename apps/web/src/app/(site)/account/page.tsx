import type { Metadata } from "next";
import { AccountPanel } from "@/components/AccountPanel";

export const metadata: Metadata = { title: "Account" };

export default function AccountPage() {
  return (
    <section className="page-head" aria-labelledby="account-title">
      <h1 id="account-title">Account</h1>
      <AccountPanel />
    </section>
  );
}
