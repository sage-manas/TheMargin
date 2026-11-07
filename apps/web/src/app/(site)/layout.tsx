import Link from "next/link";
import { SiteNav } from "@/components/SiteNav";

export default function SiteLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <a className="skip-link" href="#main">
        Skip to content
      </a>
      <header className="site-header">
        <div className="wrap">
          <Link className="wordmark" href="/">
            THE MARGIN
          </Link>
          <SiteNav />
        </div>
      </header>
      <main id="main" className="wrap">
        {children}
      </main>
      <footer className="site-footer">
        <div className="wrap">
          <span>The Margin. Every drawing, sound and letter is original.</span>
          <span>Progress is saved in this browser.</span>
        </div>
      </footer>
    </>
  );
}
