"use client";
import React, { useEffect } from "react";
import SpaceCard from "../SpaceCard/SpaceCard";
import { useState } from "react";

import { ethers } from "ethers";
import { spaceMarketplaceAddress } from "../Config/Config";

const spaceABI = require("../ABI/spaceABI.json");

export default function Space() {
  // const allSpaces = useAppSelector((state) => state.spaces.spaces);
  const [allSpaces, setAllSpaces] = useState([]);
  const [allBalances, setAllBalances] = useState([]);

  useEffect(() => {
    async function loadSpaces() {
      const provider = new ethers.providers.JsonRpcProvider(
        process.env.NEXT_PUBLIC_ALCHEMY_KEY!
      );

      const spaceContract = new ethers.Contract(
        spaceMarketplaceAddress,
        spaceABI,
        provider
      );

      const _balances = await spaceContract.getCurrentRemainingBalances();

      setAllBalances(_balances);

      const allSpaces = await spaceContract.getAllClaimedSpaces();
      setAllSpaces(allSpaces);
    }
    loadSpaces();
  }, []);

  return (
    <div className="pt-24 grid grid-cols-[repeat(auto-fill,minmax(300px,1fr))] gap-6 mx-10 pb-10">
      {allSpaces.map((space: any, index: number) => {
        return (
          <SpaceCard
            key={index}
            id={index + 1}
            exists={space.exists}
            owner={space.owner}
            balance={allBalances[index]}
            highestOffer={space.highestOffer}
            highestOfferer={space.highestOfferer}
            spaceUri={space.spaceUri}
            subscTime={space.subscTime}
            subscBurn={space.subscBurn}
            subscOffer={space.subscOffer}
          />
        );
      })}
    </div>
  );
}
