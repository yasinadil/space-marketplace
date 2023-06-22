"use client";
import React from "react";
import { ConnectWallet } from "@thirdweb-dev/react";
import Link from "next/link";

export default function Navbar() {
  return (
    <>
      <div className="hidden md:block">
        <div className="flex justify-between items-center mx-4 md:mx-10 py-6 ">
          <h1 className="font-bold text-xl md:text-3xl flex items-center">
            <Link href={"/"}>Space Marketplace</Link>
          </h1>
          <div className="flex gap-4 justify-center items-center">
            <Link
              className="font-semibold underline decoration-black text-lg"
              href="https://congruous-iberis-50b.notion.site/Space-DAO-fda2937595db4fdcbac9b3340cb04652"
              target="blank"
            >
              Docs
            </Link>

            <ConnectWallet theme="light" btnTitle="Connect Wallet" />
          </div>
        </div>
      </div>
      <div className="block md:hidden">
        <div className="navbar bg-base-100 ">
          <div className="flex-1">
            <Link href={"/"} className="btn btn-ghost normal-case text-xl">
              Space Marketplace
            </Link>
          </div>

          <div className="flex-none">
            <div className="dropdown dropdown-end">
              <label tabIndex={0} className="btn btn-ghost btn-circle avatar">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  className="h-5 w-5"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    d="M4 6h16M4 12h16M4 18h7"
                  />
                </svg>
              </label>
              <ul
                tabIndex={0}
                className="menu menu-sm dropdown-content mt-3 z-[1] p-2 shadow-xl bg-base-100 rounded-box w-52"
              >
                <li className="flex items-center justify-center rounded-lg bg-black text-white mb-2">
                  <Link
                    className="underline decoration-black text-lg text-center"
                    href="https://congruous-iberis-50b.notion.site/Space-DAO-fda2937595db4fdcbac9b3340cb04652"
                    target="blank"
                  >
                    Docs
                  </Link>
                </li>
                <li>
                  <ConnectWallet theme="light" btnTitle="Connect Wallet" />
                </li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
