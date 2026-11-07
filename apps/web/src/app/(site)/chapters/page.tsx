import type { Metadata } from "next";
import { ChapterList } from "@/components/ChapterList";

export const metadata: Metadata = { title: "Chapters" };

export default function ChaptersPage() {
  return (
    <section className="page-head" aria-labelledby="chapters-title">
      <h1 id="chapters-title">Chapters</h1>
      <p>Each chapter adds one new rule to the page, then mixes it with the ones before. Chapter 1 is ready to play.</p>
      <ChapterList />
      <p className="note">Progress shown here comes from this browser. Accounts and cloud saves are on the way.</p>
    </section>
  );
}
