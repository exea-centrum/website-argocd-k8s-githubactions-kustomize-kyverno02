#!/bin/bash

# Skrypt do automatycznego utworzenia Next.js portfolio Dawida Trojanowskiego
# Uruchom: chmod +x setup-portfolio.sh && ./setup-portfolio.sh
# Wymagania: Node.js 18+, npm

set -e  # Wyjście przy błędzie

PROJECT_NAME="dawid-portfolio"
echo "🚀 Tworzenie projektu Next.js: $PROJECT_NAME..."

# 1. Utwórz projekt
npx create-next-app@latest $PROJECT_NAME \
  --typescript \
  --tailwind \
  --eslint \
  --app \
  --src-dir \
  --import-alias "@/*" \
  --yes \
  --use-npm

cd $PROJECT_NAME

# 2. Zainstaluj zależności
echo "📦 Instalacja zależności..."
npm install gsap \
  @tsparticles/react \
  @tsparticles/slim \
  @tsparticles/preset-links \
  @tsparticles/interaction-external-repulse \
  @tsparticles/interaction-external-push \
  @emailjs/browser \
  next-themes \
  @uiw/react-codemirror \
  @codemirror/lang-python \
  @uiw/codemirror-theme-okaidia \
  @pyodide/pyodide

npm install --save-dev @types/node

# 3. Utwórz katalogi
mkdir -p src/components/sections

# 4. Nadpisz pliki
echo "✏️  Tworzenie plików..."

# globals.css
cat << 'EOF' > src/app/globals.css
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  html {
    scroll-behavior: smooth;
  }
}

@layer components {
  .skill-bar {
    @apply h-2 bg-white/10 rounded-full overflow-hidden;
  }
  .skill-progress {
    @apply h-full rounded-full transition-all duration-1500;
  }
  .hamburger {
    @apply flex flex-col cursor-pointer md:hidden;
  }
  .hamburger span {
    @apply w-6 h-0.5 bg-purple-400 my-1 transition-all duration-300;
  }
  .hamburger.active span:nth-child(1) {
    @apply rotate-45 translate-y-1.5;
  }
  .hamburger.active span:nth-child(2) {
    @apply opacity-0;
  }
  .hamburger.active span:nth-child(3) {
    @apply -rotate-45 -translate-y-1.5;
  }
}

@keyframes fadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
.animate-fade-in { animation: fadeIn 0.5s ease-out; }
@keyframes typewriter { from { width: 0; } to { width: 100%; } }
.typewriter { overflow: hidden; border-right: 2px solid #c084fc; white-space: nowrap; animation: typewriter 2s steps(40) forwards, blink 0.75s step-end infinite; }
@keyframes blink { 50% { border-color: transparent; } }
EOF

# layout.tsx
cat << 'EOF' > src/app/layout.tsx
import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { ThemeProvider } from "next-themes";
import Particles from "@/components/Particles";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Dawid Trojanowski - Portfolio",
  description: "Portfolio Dawida Trojanowskiego - Informatyka, AI, Python",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="pl" suppressHydrationWarning>
      <body className={inter.className}>
        <ThemeProvider attribute="class" defaultTheme="dark" enableSystem={false}>
          <Particles />
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
EOF

# page.tsx
cat << 'EOF' > src/app/page.tsx
"use client";

import { useState, useEffect } from "react";
import { useTheme } from "next-themes";
import gsap from "gsap";
import Header from "@/components/Header";
import Intro from "@/components/sections/Intro";
import Edu from "@/components/sections/Edu";
import Exp from "@/components/sections/Exp";
import Skills from "@/components/sections/Skills";
import Projects from "@/components/sections/Projects";
import Playground from "@/components/sections/Playground";
import Contact from "@/components/sections/Contact";

const sections = {
  intro: <Intro />,
  edu: <Edu />,
  exp: <Exp />,
  skills: <Skills />,
  proj: <Projects />,
  playground: <Playground />,
  contact: <Contact />,
};

export default function Home() {
  const [activeTab, setActiveTab] = useState("intro");
  const [mounted, setMounted] = useState(false);
  const { theme, setTheme } = useTheme();

  useEffect(() => {
    setMounted(true);
  }, []);

  useEffect(() => {
    if (activeTab === "skills") {
      gsap.from(".skill-progress", {
        width: 0,
        duration: 1.5,
        stagger: 0.1,
        ease: "power3.out",
      });
    }
  }, [activeTab]);

  if (!mounted) {
    return <div className="min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900" />;
  }

  const bgClass = theme === "light" 
    ? "bg-gradient-to-br from-slate-100 via-purple-100 to-slate-100 text-slate-900" 
    : "bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900 text-white";

  return (
    <main className={`min-h-screen transition-colors duration-500 ${bgClass}`}>
      <Header activeTab={activeTab} setActiveTab={setActiveTab} theme={theme!} setTheme={setTheme} />
      <div className="container mx-auto px-6 py-12 relative z-10">
        {sections[activeTab as keyof typeof sections]}
      </div>
      <footer className={`border-t ${theme === "light" ? "border-slate-300/30 bg-white/20" : "border-purple-500/30 bg-black/20"} backdrop-blur-sm mt-16`}>
        <div className="container mx-auto px-6 py-8 text-center text-gray-400 dark:text-gray-400">
          <p>Dawid Trojanowski © 2024. Zbudowane z Next.js 14 + bajerami 🐙</p>
        </div>
      </footer>
    </main>
  );
}
EOF

# Components...
# Header.tsx
cat << 'EOF' > src/components/Header.tsx
"use client";

import { useState } from "react";

interface HeaderProps {
  activeTab: string;
  setActiveTab: (tab: string) => void;
  theme: string;
  setTheme: (theme: "dark" | "light") => void;
}

export default function Header({ activeTab, setActiveTab, theme, setTheme }: HeaderProps) {
  const [isOpen, setIsOpen] = useState(false);

  const tabs = [
    { id: "intro", label: "O Mnie" },
    { id: "edu", label: "Edukacja" },
    { id: "exp", label: "Doświadczenie" },
    { id: "skills", label: "Umiejętności" },
    { id: "proj", label: "Projekty" },
    { id: "playground", label: "Python Playground" },
    { id: "contact", label: "Kontakt" },
  ];

  return (
    <header className={`border-b ${theme === "light" ? "border-slate-300/30 bg-white/20" : "border-purple-500/30 bg-black/20"} backdrop-blur-sm sticky top-0 z-50 transition-colors duration-500`}>
      <div className="container mx-auto px-6 py-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <svg className="w-10 h-10 text-purple-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a