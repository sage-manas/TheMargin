import Link from "next/link";

export default function NotFound() {
  return (
    <main id="main" className="wrap page-head">
      <span className="caption">Hmm.</span>
      <h1>This page was never drawn</h1>
      <p>
        <Link href="/">Back to the front cover</Link>
      </p>
    </main>
  );
}
