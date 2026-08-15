import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: { default: "SF6 Rating", template: "%s | SF6 Rating" },
  description: "SF6 Rating web application",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return children;
}
