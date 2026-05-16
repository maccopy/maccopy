import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: "class",
  content: [
    "./app/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        swift: {
          red:    "#F05138",
          orange: "#FF9500",
          coral:  "#FF6B35",
        },
      },
      fontFamily: {
        sans: [
          "-apple-system",
          "BlinkMacSystemFont",
          '"SF Pro Display"',
          '"Segoe UI"',
          "sans-serif",
        ],
        mono: [
          '"SF Mono"',
          '"JetBrains Mono"',
          "Menlo",
          "monospace",
        ],
      },
      backgroundImage: {
        "swift-gradient": "linear-gradient(135deg, #FF6B35 0%, #F05138 50%, #C0392B 100%)",
        "hero-glow":
          "radial-gradient(ellipse 80% 60% at 50% -10%, rgba(240,81,56,0.18) 0%, transparent 70%)",
      },
      animation: {
        "fade-up": "fadeUp 0.6s ease both",
      },
      keyframes: {
        fadeUp: {
          "0%": { opacity: "0", transform: "translateY(20px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
      },
    },
  },
  plugins: [],
};

export default config;
