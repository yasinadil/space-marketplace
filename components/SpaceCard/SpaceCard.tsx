"use client";
import React from "react";
import Image from "next/image";
import space from "../../public/assets/space.png";
import Link from "next/link";
import polygon from "../../public/assets/polygon.png";
import offer from "../../public/assets/offer.png";
import { ethers } from "ethers";

export default async function SpaceCard(props: any) {
  let spaceUri = props.spaceUri;
  if (spaceUri != "") {
    spaceUri = `https://w3s.link/ipfs/${spaceUri.split("ipfs://")[1]}`;

    const TokenMetadata = await fetch(spaceUri).then((response) =>
      response.json()
    );
    let TokenImage = TokenMetadata.image;
    // if (TokenImage.startsWith("ipfs://")) {
    //   TokenImage = `https://w3s.link/ipfs/${
    //     TokenImage.split("ipfs://")[1]
    //   }`;
    // }
    spaceUri = TokenImage;
  }
  return (
    <div className="card object-cover w-[100%] h-[100%] bg-base-100 shadow-xl">
      <figure className="cursor-pointer bg-black">
        <Link href={`/space/${props.id}`}>
          {spaceUri != "" ? (
            <img className="h-[200px]" src={spaceUri} alt="spaceImage" />
          ) : (
            <Image className="h-[200px]" src={space} alt="Shoes" />
          )}
        </Link>
      </figure>
      <div className="card-body">
        <h2 className="card-title">
          <Link href={`/space/${props.id}`}>
            Space #{props.id < 10 && "0"}
            {props.id}
          </Link>
          <div className="badge badge-secondary">
            {props.exists ? "CLAIMED" : "UNCLAIMED"}
          </div>
        </h2>

        <div className="card-actions justify-end pt-2">
          <div className="badge border-0 tooltip flex" data-tip="offer">
            <Image className="w-7 pr-1" src={offer} alt="offer" />
            {ethers.utils.formatEther(props.highestOffer.toString())}
          </div>
          <div className="badge border-0 tooltip flex" data-tip="balance">
            <Image className="w-7 pr-1" src={polygon} alt="balance" />
            {ethers.utils.formatEther(props.balance.toString())}
          </div>
        </div>
      </div>
    </div>
  );
}
