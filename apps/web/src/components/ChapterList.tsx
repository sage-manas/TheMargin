"use client";
import { useEffect, useState } from "react";
import { CHAPTERS, pageLabel } from "@the-margin/contracts/chapters";
import { chapterProgress, readLocalProgress, type SaveProgress } from "@/lib/progress.ts";
import { browserStorage } from "@/lib/storage.ts";

export function ChapterList() {
  const [save, setSave] = useState<SaveProgress | null>(null);
  useEffect(() => setSave(readLocalProgress(browserStorage())), []);

  return (
    <ol className="chapters">
      {CHAPTERS.map((ch) => {
        const p = chapterProgress(save, ch);
        const done = p.status === "completed" ? ch.pages.length : p.status === "in-progress" ? p.pagesDone : 0;
        return (
          <li key={ch.id} className={`panel chapter${ch.released ? "" : " unreleased"}`} data-chapter={ch.id} data-status={p.status}>
            <span className="chapter-number">Chapter {ch.number}</span>
            <h2>{ch.title}</h2>
            {ch.released && (
              <div
                className="meter"
                role="progressbar"
                aria-label={`Chapter ${ch.number} progress`}
                aria-valuemin={0}
                aria-valuemax={ch.pages.length}
                aria-valuenow={done}
              >
                <span style={{ width: `${(100 * done) / ch.pages.length}%` }} />
              </div>
            )}
            <p className="chapter-status">
              {p.status === "unreleased" && "Still being drawn."}
              {p.status === "not-started" && `${ch.pages.length} pages. Not started.`}
              {p.status === "in-progress" && `${p.pagesDone} of ${ch.pages.length} pages. On page ${pageLabel(p.currentPage)}.`}
              {p.status === "completed" && "Completed."}
            </p>
            {ch.released && (
              <a href="/play">{p.status === "in-progress" ? "Continue" : p.status === "completed" ? "Play again" : "Start"}</a>
            )}
          </li>
        );
      })}
    </ol>
  );
}
