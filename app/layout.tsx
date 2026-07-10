import type { Metadata } from "next";
import { Cormorant_Garamond, Geist } from "next/font/google";
import { enVoicePack } from "@/lib/voice-packs";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const cormorant = Cormorant_Garamond({
  variable: "--font-cormorant",
  subsets: ["latin"],
  weight: ["300", "400"],
});

export const metadata: Metadata = {
  title: enVoicePack.strings.wordmark,
  description: enVoicePack.strings.whatsOnYourMind,
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${cormorant.variable} h-full antialiased`}
    >
      <body className="min-h-screen bg-[var(--lb-bg)] font-sans text-[var(--lb-fg)]">
        {children}
      </body>
    </html>
  );
}
