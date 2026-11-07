import type { Metadata } from "next";
import { Launcher } from "@/game/Launcher";
import "./play.css";

export const metadata: Metadata = { title: "Play" };

export default function PlayPage() {
  return (
    <main>
      <h1 className="visually-hidden">Play The Margin</h1>
      <Launcher />
    </main>
  );
}
