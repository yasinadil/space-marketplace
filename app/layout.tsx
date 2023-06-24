import "./globals.css";
import Navbar from "@/components/Navbar/Navbar";
import { Inter } from "next/font/google";
import { ThirdWebProviderWrapper } from "./ThirdWeb/thirdwebprovider";

const inter = Inter({ subsets: ["latin"] });

export const metadata = {
  title: "Space Marketplace",
  description: "Display your NFTs in our spaces!",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={inter.className} cz-shortcut-listen={"true"}>
        <ThirdWebProviderWrapper>
          <Navbar />
          {children}
        </ThirdWebProviderWrapper>
      </body>
    </html>
  );
}
