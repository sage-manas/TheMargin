import type { Metadata } from "next";
import { SettingsForm } from "@/components/SettingsForm";

export const metadata: Metadata = { title: "Settings" };

export default function SettingsPage() {
  return (
    <section className="page-head" aria-labelledby="settings-title">
      <h1 id="settings-title">Settings</h1>
      <p>These match the game&rsquo;s own pause menu: change them in either place.</p>
      <SettingsForm />
    </section>
  );
}
