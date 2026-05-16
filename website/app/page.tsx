"use client";

import { useState, useEffect } from "react";

const GITHUB = "https://github.com/FernandoHaeser/macos-clipboard-manager";
const RELEASES = `${GITHUB}/releases/latest`;
const VERSION = "1.1.1";
const BREW_CMD = `brew tap maccopy/homebrew-tap\nbrew install --cask maccopy`;

// ── Theme ──────────────────────────────────────────────────────────────────────

function useTheme() {
  const [dark, setDark] = useState(false);

  useEffect(() => {
    setDark(document.documentElement.classList.contains("dark"));
  }, []);

  const toggle = () => {
    const next = !dark;
    setDark(next);
    document.documentElement.classList.toggle("dark", next);
    localStorage.setItem("theme", next ? "dark" : "light");
  };

  return { dark, toggle };
}

// ── Icons ──────────────────────────────────────────────────────────────────────

function MaccopyLogo({ className = "w-8 h-8" }: { className?: string }) {
  return (
    <svg viewBox="0 0 100 110" fill="none" xmlns="http://www.w3.org/2000/svg" className={className}>
      {/* back page */}
      <rect x="35" y="44" width="44" height="54" rx="10" fill="currentColor" opacity="0.4" />
      {/* front page */}
      <rect x="22" y="36" width="44" height="54" rx="10" fill="currentColor" />
      {/* leaf */}
      <path d="M44,36 C44,26 50,16 57,12 C59,20 55,30 45,35 C44.5,35.5 44,36 44,36Z" fill="currentColor" />
    </svg>
  );
}

function IconGitHub() {
  return (
    <svg viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5">
      <path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12" />
    </svg>
  );
}

function IconDownload() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" className="w-4 h-4">
      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
      <polyline points="7 10 12 15 17 10" />
      <line x1="12" y1="15" x2="12" y2="3" />
    </svg>
  );
}

function IconCopy() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" className="w-4 h-4">
      <rect x="9" y="9" width="13" height="13" rx="2" />
      <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
    </svg>
  );
}

function IconCheck() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.5} strokeLinecap="round" strokeLinejoin="round" className="w-4 h-4">
      <polyline points="20 6 9 17 4 12" />
    </svg>
  );
}

function IconSun() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" className="w-4 h-4">
      <circle cx="12" cy="12" r="5" />
      <line x1="12" y1="1" x2="12" y2="3" />
      <line x1="12" y1="21" x2="12" y2="23" />
      <line x1="4.22" y1="4.22" x2="5.64" y2="5.64" />
      <line x1="18.36" y1="18.36" x2="19.78" y2="19.78" />
      <line x1="1" y1="12" x2="3" y2="12" />
      <line x1="21" y1="12" x2="23" y2="12" />
      <line x1="4.22" y1="19.78" x2="5.64" y2="18.36" />
      <line x1="18.36" y1="5.64" x2="19.78" y2="4.22" />
    </svg>
  );
}

function IconMoon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" className="w-4 h-4">
      <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
    </svg>
  );
}

// ── Copy button ────────────────────────────────────────────────────────────────

function CopyButton({ text }: { text: string }) {
  const [copied, setCopied] = useState(false);
  const copy = () => {
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };
  return (
    <button
      onClick={copy}
      className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium
                 text-gray-400 hover:text-white hover:bg-white/10 transition-all duration-150"
      aria-label="Copy"
    >
      {copied ? <IconCheck /> : <IconCopy />}
      {copied ? "Copied!" : "Copy"}
    </button>
  );
}

// ── Navbar ─────────────────────────────────────────────────────────────────────

function ThemeToggle() {
  const { dark, toggle } = useTheme();
  return (
    <button
      onClick={toggle}
      aria-label="Toggle theme"
      className="w-9 h-9 flex items-center justify-center rounded-xl border border-gray-200 dark:border-gray-700
                 text-gray-500 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800
                 transition-all duration-200"
    >
      {dark ? <IconSun /> : <IconMoon />}
    </button>
  );
}

function Navbar() {
  return (
    <header className="sticky top-0 z-50 border-b border-gray-100 dark:border-gray-800 bg-white/80 dark:bg-gray-950/80 backdrop-blur-xl">
      <div className="max-w-6xl mx-auto px-6 h-16 flex items-center justify-between">
        <a href="#" className="flex items-center gap-2.5 font-bold text-xl text-gray-900 dark:text-white hover:opacity-80 transition-opacity">
          <span className="w-8 h-8 rounded-xl flex items-center justify-center text-white shadow-sm"
                style={{ background: "linear-gradient(135deg, #FF6B35, #F05138)" }}>
            <MaccopyLogo className="w-5 h-5" />
          </span>
          Maccopy
        </a>

        <nav className="hidden md:flex items-center gap-6 text-sm text-gray-600 dark:text-gray-400">
          <a href="#features" className="hover:text-gray-900 dark:hover:text-white transition-colors">Features</a>
          <a href="#install"  className="hover:text-gray-900 dark:hover:text-white transition-colors">Install</a>
          <a href={GITHUB} target="_blank" rel="noopener" className="hover:text-gray-900 dark:hover:text-white transition-colors flex items-center gap-1.5">
            <IconGitHub /> GitHub
          </a>
        </nav>

        <div className="flex items-center gap-2">
          <ThemeToggle />
          <a href={RELEASES} target="_blank" rel="noopener" className="btn-primary text-xs px-4 py-2">
            <IconDownload /> Download v{VERSION}
          </a>
        </div>
      </div>
    </header>
  );
}

// ── Hero ───────────────────────────────────────────────────────────────────────

function Hero() {
  return (
    <section className="relative overflow-hidden pt-20 pb-28">
      <div className="absolute inset-0 bg-hero-glow pointer-events-none" />
      <div className="absolute -top-32 left-1/2 -translate-x-1/2 w-[600px] h-[600px] rounded-full opacity-[0.07] blur-3xl pointer-events-none"
           style={{ background: "radial-gradient(circle, #F05138, #FF9500)" }} />

      <div className="relative max-w-6xl mx-auto px-6 text-center">
        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full border border-orange-200 dark:border-orange-900/50 bg-orange-50 dark:bg-orange-950/40 text-swift-red text-xs font-semibold mb-8 animate-fade-up">
          <span className="w-1.5 h-1.5 rounded-full bg-swift-red animate-pulse" />
          macOS 14 Sonoma+ · Free &amp; Open Source
        </div>

        <h1 className="text-5xl md:text-7xl font-bold tracking-tight text-gray-900 dark:text-white leading-[1.08] mb-6 animate-fade-up"
            style={{ animationDelay: "0.05s" }}>
          Clipboard history<br />
          <span className="gradient-text">always at hand</span>
        </h1>

        <p className="max-w-xl mx-auto text-lg md:text-xl text-gray-500 dark:text-gray-400 leading-relaxed mb-10 animate-fade-up"
           style={{ animationDelay: "0.1s" }}>
          Native macOS menu bar app for text, images&nbsp;&amp;&nbsp;files.
          Zero dependencies. One hotkey away.
        </p>

        <div className="flex flex-wrap items-center justify-center gap-3 mb-12 animate-fade-up"
             style={{ animationDelay: "0.15s" }}>
          <a href={RELEASES} target="_blank" rel="noopener" className="btn-primary">
            <IconDownload /> Download v{VERSION}
          </a>
          <a href={GITHUB} target="_blank" rel="noopener" className="btn-ghost">
            <IconGitHub /> View on GitHub
          </a>
        </div>

        <div className="inline-block max-w-lg w-full text-left animate-fade-up"
             style={{ animationDelay: "0.2s" }}>
          <div className="code-block">
            <div className="flex items-center justify-between mb-3">
              <div className="flex gap-1.5">
                <span className="w-3 h-3 rounded-full bg-red-500 opacity-70" />
                <span className="w-3 h-3 rounded-full bg-yellow-400 opacity-70" />
                <span className="w-3 h-3 rounded-full bg-green-500 opacity-70" />
              </div>
              <CopyButton text={BREW_CMD} />
            </div>
            {BREW_CMD.split("\n").map((line, i) => (
              <div key={i} className="flex items-center gap-2">
                <span className="text-swift-coral select-none">$</span>
                <span className="text-gray-100">{line}</span>
              </div>
            ))}
          </div>
          <p className="text-center text-xs text-gray-400 mt-3">
            Or{" "}
            <a href={RELEASES} className="text-swift-red hover:underline" target="_blank" rel="noopener">
              download the DMG
            </a>{" "}
            directly — no Homebrew required.
          </p>
        </div>
      </div>
    </section>
  );
}

// ── App visual mockup ──────────────────────────────────────────────────────────

function AppMockup() {
  const items = [
    { icon: "🔗", text: "github.com/maccopy/app", sub: "2 sec ago · github.com", pinned: true },
    { icon: "📄", text: "Native macOS clipboard history manager", sub: "1 min ago · 38 chars" },
    { icon: "🖼", text: "Image", sub: "5 min ago" },
    { icon: "📄", text: "brew tap maccopy/homebrew-tap", sub: "12 min ago · 29 chars" },
    { icon: "📄", text: "com.maccopy.maccopy", sub: "20 min ago · 19 chars" },
  ];

  return (
    <section className="py-8 pb-20">
      <div className="max-w-6xl mx-auto px-6 flex justify-center">
        <div className="w-full max-w-sm rounded-2xl overflow-hidden shadow-2xl border border-gray-200 dark:border-gray-700 backdrop-blur-xl
                        bg-[rgba(255,255,255,0.92)] dark:bg-[rgba(18,18,22,0.92)]">
          <div className="px-4 py-3 border-b border-gray-100 dark:border-gray-700/60">
            <div className="flex items-center gap-2 text-gray-400 dark:text-gray-500">
              <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                <circle cx="11" cy="11" r="8" /><path d="m21 21-4.35-4.35" />
              </svg>
              <span className="text-sm">Search clipboard history…</span>
            </div>
          </div>

          <div className="py-1.5">
            {items.map((item, i) => (
              <div key={i}
                   className={`flex items-center gap-3 px-4 py-2.5 mx-2 rounded-xl ${i === 0 ? "border border-orange-200 dark:border-orange-900/60" : ""}`}
                   style={i === 0 ? { background: "rgba(240,81,56,0.08)" } : {}}>
                <span className="text-lg w-6 shrink-0">{item.icon}</span>
                <div className="min-w-0">
                  <div className="text-xs font-medium text-gray-800 dark:text-gray-100 truncate">{item.text}</div>
                  <div className="text-[10px] text-gray-400 dark:text-gray-500 flex items-center gap-1">
                    {item.pinned && <span className="text-orange-400">📌</span>}
                    {item.sub}
                  </div>
                </div>
                {i === 0 && (
                  <div className="ml-auto flex gap-1 shrink-0">
                    <span className="w-6 h-6 rounded-lg flex items-center justify-center text-[10px] bg-orange-100 dark:bg-orange-950/60 text-orange-500">📌</span>
                    <span className="w-6 h-6 rounded-lg flex items-center justify-center text-[10px] bg-blue-50 dark:bg-blue-950/40 text-blue-500">↑</span>
                    <span className="w-6 h-6 rounded-lg flex items-center justify-center text-[10px] bg-red-50 dark:bg-red-950/40 text-red-400">🗑</span>
                  </div>
                )}
              </div>
            ))}
          </div>

          <div className="px-4 py-2 border-t border-gray-100 dark:border-gray-700/60 flex items-center justify-between">
            <span className="text-[10px] text-gray-400 dark:text-gray-500">📋 47 items</span>
            <div className="flex gap-3 text-[10px]">
              <span className="px-1.5 py-0.5 rounded border border-gray-200 dark:border-gray-600 text-gray-400 dark:text-gray-500">↑↓</span>
              <span className="px-1.5 py-0.5 rounded border border-gray-200 dark:border-gray-600 text-gray-400 dark:text-gray-500">↵ paste</span>
              <span className="px-1.5 py-0.5 rounded border border-gray-200 dark:border-gray-600 text-gray-400 dark:text-gray-500">⌘K clear</span>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

// ── Features ───────────────────────────────────────────────────────────────────

const FEATURES = [
  {
    icon: "📋",
    title: "Full clipboard history",
    desc: "Stores text, images, and files. Up to 1000 items with configurable limit. Pinned items stay at the top.",
  },
  {
    icon: "⌨️",
    title: "Keyboard first",
    desc: "⌘⇧V to open. Arrow keys navigate. ↵ pastes. ⌘1–9 instant-paste the first 9 items without lifting your hands.",
  },
  {
    icon: "🔗",
    title: "Link previews",
    desc: "URLs automatically show the page favicon and title. Domain shown in the metadata row instead of a raw link.",
  },
  {
    icon: "🎨",
    title: "Fully customizable",
    desc: "9 accent colors, dark/light/system theme, glass blur toggle, overlay opacity, row density, and popover width.",
  },
  {
    icon: "🔄",
    title: "Automatic updates",
    desc: "Detects new releases from GitHub and installs silently in the background. Changelog popup appears after relaunch.",
  },
  {
    icon: "☁️",
    title: "iCloud sync",
    desc: "Optionally syncs text history to iCloud Drive so your clipboard follows you across Macs.",
  },
];

function Features() {
  return (
    <section id="features" className="py-24 bg-gray-50 dark:bg-gray-900/60">
      <div className="max-w-6xl mx-auto px-6">
        <div className="text-center mb-16">
          <p className="section-label mb-3">Features</p>
          <h2 className="text-3xl md:text-4xl font-bold text-gray-900 dark:text-white">
            Everything you need, nothing you don&apos;t
          </h2>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-5">
          {FEATURES.map((f) => (
            <div key={f.title} className="feature-card group">
              <div className="w-11 h-11 rounded-xl flex items-center justify-center text-xl mb-4
                              bg-orange-50 dark:bg-orange-950/40 group-hover:bg-orange-100 dark:group-hover:bg-orange-900/40 transition-colors">
                {f.icon}
              </div>
              <h3 className="font-semibold text-gray-900 dark:text-white mb-2">{f.title}</h3>
              <p className="text-sm text-gray-500 dark:text-gray-400 leading-relaxed">{f.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

// ── Install ────────────────────────────────────────────────────────────────────

function InstallSection() {
  return (
    <section id="install" className="py-24">
      <div className="max-w-6xl mx-auto px-6">
        <div className="text-center mb-16">
          <p className="section-label mb-3">Install</p>
          <h2 className="text-3xl md:text-4xl font-bold text-gray-900 dark:text-white">
            Three ways to get started
          </h2>
        </div>

        <div className="grid md:grid-cols-3 gap-6">
          {/* Homebrew */}
          <div className="rounded-2xl border-2 border-swift-red/20 dark:border-swift-red/30 bg-gradient-to-b from-orange-50 to-white dark:from-orange-950/30 dark:to-gray-950 p-6 relative overflow-hidden">
            <div className="absolute top-4 right-4">
              <span className="text-[10px] font-bold tracking-wider uppercase text-swift-red bg-orange-100 dark:bg-orange-950/60 px-2 py-0.5 rounded-full">
                Recommended
              </span>
            </div>
            <div className="text-3xl mb-4">🍺</div>
            <h3 className="font-bold text-gray-900 dark:text-white mb-1">Homebrew</h3>
            <p className="text-sm text-gray-500 dark:text-gray-400 mb-5">Install and update with one command.</p>
            <div className="code-block text-xs space-y-1">
              <div className="flex gap-2"><span className="text-swift-coral">$</span><span>brew tap maccopy/homebrew-tap</span></div>
              <div className="flex gap-2"><span className="text-swift-coral">$</span><span>brew install --cask maccopy</span></div>
            </div>
          </div>

          {/* DMG */}
          <div className="rounded-2xl border border-gray-100 dark:border-gray-700 bg-white dark:bg-gray-800/50 p-6 shadow-sm">
            <div className="text-3xl mb-4">💿</div>
            <h3 className="font-bold text-gray-900 dark:text-white mb-1">Direct download</h3>
            <p className="text-sm text-gray-500 dark:text-gray-400 mb-5">Open the DMG and run the installer package.</p>
            <a href={RELEASES} target="_blank" rel="noopener" className="btn-ghost w-full justify-center text-xs">
              <IconDownload /> Download v{VERSION} DMG
            </a>
          </div>

          {/* One-liner */}
          <div className="rounded-2xl border border-gray-100 dark:border-gray-700 bg-white dark:bg-gray-800/50 p-6 shadow-sm">
            <div className="text-3xl mb-4">⚡</div>
            <h3 className="font-bold text-gray-900 dark:text-white mb-1">One-line installer</h3>
            <p className="text-sm text-gray-500 dark:text-gray-400 mb-5">Downloads pre-built or builds from source automatically.</p>
            <div className="code-block text-xs">
              <div className="flex gap-2 items-start">
                <span className="text-swift-coral shrink-0">$</span>
                <span className="break-all">curl -fsSL https://raw.githubusercontent.com/FernandoHaeser/macos-clipboard-manager/main/install.sh | bash</span>
              </div>
            </div>
          </div>
        </div>

        <p className="text-center text-sm text-gray-400 dark:text-gray-500 mt-8">
          Requires <strong className="text-gray-600 dark:text-gray-300">macOS 14 Sonoma</strong> or later. Free and open source under the MIT License.
        </p>
      </div>
    </section>
  );
}

// ── Permissions ────────────────────────────────────────────────────────────────

function PermissionsSection() {
  return (
    <section className="py-20 bg-gray-50 dark:bg-gray-900/60">
      <div className="max-w-4xl mx-auto px-6 text-center">
        <p className="section-label mb-3">Permissions</p>
        <h2 className="text-3xl font-bold text-gray-900 dark:text-white mb-4">
          Two permissions, for good reason
        </h2>
        <p className="text-gray-500 dark:text-gray-400 mb-12 max-w-xl mx-auto">
          Maccopy requests the minimum permissions it needs. The Setup Wizard guides you through both on first launch.
        </p>

        <div className="grid md:grid-cols-2 gap-5 text-left">
          <div className="feature-card">
            <div className="flex items-start gap-4">
              <div className="w-10 h-10 rounded-xl bg-blue-50 dark:bg-blue-950/40 flex items-center justify-center shrink-0 text-lg">🖱</div>
              <div>
                <h3 className="font-semibold text-gray-900 dark:text-white mb-1">Accessibility</h3>
                <p className="text-sm text-gray-500 dark:text-gray-400">Needed to simulate ⌘V and paste the selected item into the active application.</p>
              </div>
            </div>
          </div>
          <div className="feature-card">
            <div className="flex items-start gap-4">
              <div className="w-10 h-10 rounded-xl bg-purple-50 dark:bg-purple-950/40 flex items-center justify-center shrink-0 text-lg">⌨️</div>
              <div>
                <h3 className="font-semibold text-gray-900 dark:text-white mb-1">Input Monitoring</h3>
                <p className="text-sm text-gray-500 dark:text-gray-400">Needed to detect the global hotkey ⌘⇧V while other apps are in focus.</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

// ── Open source CTA ────────────────────────────────────────────────────────────

function OpenSourceCTA() {
  return (
    <section className="py-24">
      <div className="max-w-4xl mx-auto px-6">
        <div className="rounded-3xl p-px"
             style={{ background: "linear-gradient(135deg, #FF6B35, #F05138, #C0392B)" }}>
          <div className="rounded-[calc(1.5rem-1px)] bg-white dark:bg-gray-900 px-8 py-14 text-center">
            <div className="w-16 h-16 mx-auto mb-6 rounded-2xl flex items-center justify-center text-white"
                 style={{ background: "linear-gradient(135deg, #FF6B35, #F05138)" }}>
              <MaccopyLogo className="w-10 h-10" />
            </div>
            <h2 className="text-3xl md:text-4xl font-bold text-gray-900 dark:text-white mb-4">
              Free, open source, no telemetry
            </h2>
            <p className="text-gray-500 dark:text-gray-400 max-w-xl mx-auto mb-8 text-lg">
              Maccopy is MIT-licensed. No accounts, no subscriptions, no tracking.
              Your clipboard data stays on your Mac.
            </p>
            <div className="flex flex-wrap items-center justify-center gap-3">
              <a href={GITHUB} target="_blank" rel="noopener" className="btn-primary">
                <IconGitHub /> View source on GitHub
              </a>
              <a href={`${GITHUB}/issues`} target="_blank" rel="noopener" className="btn-ghost">
                Report an issue
              </a>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

// ── Footer ─────────────────────────────────────────────────────────────────────

function Footer() {
  return (
    <footer className="border-t border-gray-100 dark:border-gray-800 py-10">
      <div className="max-w-6xl mx-auto px-6 flex flex-col md:flex-row items-center justify-between gap-4">
        <div className="flex items-center gap-2 text-gray-500 dark:text-gray-400 text-sm">
          <span className="w-6 h-6 rounded-lg flex items-center justify-center text-white text-xs"
                style={{ background: "linear-gradient(135deg, #FF6B35, #F05138)" }}>
            <MaccopyLogo className="w-4 h-4" />
          </span>
          <span>Maccopy v{VERSION}</span>
          <span className="text-gray-300 dark:text-gray-600">·</span>
          <span>MIT License</span>
        </div>

        <div className="flex items-center gap-5 text-sm text-gray-500 dark:text-gray-400">
          <a href={GITHUB} target="_blank" rel="noopener" className="hover:text-gray-900 dark:hover:text-white transition-colors flex items-center gap-1.5">
            <IconGitHub /> GitHub
          </a>
          <a href={RELEASES} target="_blank" rel="noopener" className="hover:text-gray-900 dark:hover:text-white transition-colors">
            Releases
          </a>
          <a href={`${GITHUB}/issues`} target="_blank" rel="noopener" className="hover:text-gray-900 dark:hover:text-white transition-colors">
            Issues
          </a>
        </div>
      </div>
    </footer>
  );
}

// ── Page ───────────────────────────────────────────────────────────────────────

export default function Home() {
  return (
    <>
      <Navbar />
      <main>
        <Hero />
        <AppMockup />
        <Features />
        <InstallSection />
        <PermissionsSection />
        <OpenSourceCTA />
      </main>
      <Footer />
    </>
  );
}
