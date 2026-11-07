import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: { default: "The Margin: escape the drawing", template: "%s · The Margin" },
  description:
    "A browser puzzle-adventure about a tiny ink character who discovers their world is a comic book, and that its rules can be edited.",
};

export const viewport: Viewport = { themeColor: "#f7f1e1" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
