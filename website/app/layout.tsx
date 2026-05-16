import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Maccopy — Clipboard history for macOS",
  description:
    "Native macOS menu bar app for clipboard history. Text, images and files. Zero dependencies. Free and open source.",
  openGraph: {
    title: "Maccopy",
    description: "Native macOS clipboard history manager. Lives in your menu bar.",
    type: "website",
  },
};

const themeScript = `(function(){var t=localStorage.getItem('theme');if(t==='dark'||(t===null&&window.matchMedia('(prefers-color-scheme:dark)').matches)){document.documentElement.classList.add('dark');}})();`;

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeScript }} />
      </head>
      <body>{children}</body>
    </html>
  );
}
