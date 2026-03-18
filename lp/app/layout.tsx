import type { Metadata } from "next";
import { Geist } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "シンプル文字起こし - リアルタイム音声文字起こしアプリ",
  description:
    "iPhoneで使えるリアルタイム音声文字起こしアプリ。完全オンデバイス処理でプライバシーを守りながら、会議や講義を素早くテキスト化。",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ja">
      <body className={`${geistSans.variable} antialiased`}>{children}</body>
    </html>
  );
}
