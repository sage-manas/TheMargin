import Link from "next/link";
import { HeroArt } from "@/components/HeroArt";
import { PlayLink } from "@/components/PlayLink";

const RULES = [
  {
    title: "Panels are rooms",
    text: "Rooms connect where their floors line up across the gutter. Walk off the edge of one panel and into the next.",
  },
  {
    title: "Move the room you're in",
    text: "Your hand belongs to the reader. Slide a lifted panel, even the one Nib is standing in, until the page makes a path.",
  },
  {
    title: "Words are things",
    text: "Bold words can be lifted out of a sentence. A door labelled SHUT stays shut until you give it a better word.",
  },
  {
    title: "Captions change the scene",
    text: "Drag LATER. or THAT NIGHT. into another room and time passes there: seeds grow, ice melts, people sleep. Close-ups let your hand work what's too small for Nib.",
  },
];

const CONTROLS: [string, React.ReactNode][] = [
  ["Walk", <><kbd>A</kbd> <kbd>D</kbd> or <kbd>←</kbd> <kbd>→</kbd></>],
  ["Hop", <><kbd>Space</kbd>, <kbd>W</kbd> or <kbd>↑</kbd></>],
  ["Take, place or swap a word", <kbd>E</kbd>],
  ["Slide a lifted panel", <>Drag it with the mouse, or <kbd>Q</kbd> then the arrow keys</>],
  ["Move a caption card, work a close-up", <>Drag the card, or click in the close-up; <kbd>Q</kbd> selects them too</>],
  ["Reset the page", <>Hold <kbd>R</kbd></>],
  ["Pause", <><kbd>Esc</kbd> or <kbd>P</kbd></>],
];

export default function Home() {
  return (
    <>
      <section className="hero" aria-labelledby="title">
        <div>
          <h1 id="title">The Margin</h1>
          <p className="tagline">Escape the drawing.</p>
          <p className="lede">
            Nib is a tiny ink character who has just found out that their world is a comic book. The comic&rsquo;s rules
            are only drawn on, so they can be redrawn. A puzzle-adventure for your browser, one page at a time.
          </p>
          <div className="actions">
            <PlayLink />
            <Link className="button secondary" href="/chapters">
              Chapters
            </Link>
          </div>
        </div>
        <HeroArt />
      </section>

      <section className="section" aria-labelledby="how">
        <span className="caption">Meanwhile, on the page…</span>
        <h2 id="how">How it plays</h2>
        <ul className="rules">
          {RULES.map((r) => (
            <li key={r.title} className="panel">
              <h3>{r.title}</h3>
              <p>{r.text}</p>
            </li>
          ))}
        </ul>
      </section>

      <section className="section" aria-labelledby="controls">
        <h2 id="controls">Controls</h2>
        <p>Everything can be done from the keyboard. Nothing is timed and nothing can hurt Nib.</p>
        <table className="controls">
          <tbody>
            {CONTROLS.map(([action, keys]) => (
              <tr key={action}>
                <th scope="row">{action}</th>
                <td>{keys}</td>
              </tr>
            ))}
          </tbody>
        </table>
        <p className="note">
          Plays in desktop Chrome, Edge, Firefox and Safari 17 or later. Chapter 1 is about a 10 MB download, and your
          progress is saved in this browser.
        </p>
      </section>
    </>
  );
}
