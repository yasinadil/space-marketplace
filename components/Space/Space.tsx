"use client";
import React from "react";
import SpaceCard from "../SpaceCard/SpaceCard";

// import { ethers } from "ethers";
// import { spaceMarketplaceAddress } from "../Config/Config";

// const spaceABI = require("../ABI/spaceABI.json");
import { useAppSelector } from "@/app/GlobalRedux/store";

export default async function Space() {
  const allSpaces = useAppSelector((state) => state.spaces.spaces);
  //   const provider = new ethers.providers.JsonRpcProvider(
  //     "https://polygon-mumbai.g.alchemy.com/v2/2TI0SeKoUJzCRBNaFnTGaV9B7uvkxnsy"
  //   );

  //   const spaceContract = new ethers.Contract(
  //     spaceMarketplaceAddress,
  //     spaceABI,
  //     provider
  //   );

  //   const allSpaces = await spaceContract.getAllClaimedSpaces();
  //   console.log(allSpaces);

  return (
    <div className="pt-24 grid grid-cols-[repeat(auto-fill,minmax(300px,1fr))] gap-4 mx-10">
      {allSpaces.map((space: any, index: number) => {
        return (
          <SpaceCard
            key={index}
            id={index + 1}
            exists={space.exists}
            owner={space.owner}
            balance={space.balance}
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
