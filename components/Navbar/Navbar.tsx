"use client";
import React from "react";
import { ConnectWallet } from "@thirdweb-dev/react";
import Link from "next/link";

export default function Navbar() {
  return (
    <div className="flex justify-between items-center mx-4 md:mx-10 py-6">
      <h1 className="font-bold text-3xl flex items-center">
        <Link href={"/"}>SPACE</Link>
      </h1>
      <ConnectWallet theme="light" btnTitle="Connect Wallet" />
    </div>
  );
}
