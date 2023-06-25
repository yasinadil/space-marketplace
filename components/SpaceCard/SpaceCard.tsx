"use client";
import React from "react";
import Image from "next/image";
import space from "../../public/assets/space.png";
import Link from "next/link";
import grayBalance from "../../public/assets/grayBalance.png";
import purpleBalance from "../../public/assets/purpleBalance.png";
import grayOffer from "../../public/assets/gray-offer.png";
import purpleOffer from "../../public/assets/purple-offer.png";
import { ethers } from "ethers";

export default async function SpaceCard(props: any) {
  let spaceUri = props.spaceUri;
  if (spaceUri != "") {
    spaceUri = `https://w3s.link/ipfs/${spaceUri.split("ipfs://")[1]}`;

    const TokenMetadata = await fetch(spaceUri).then((response) =>
      response.json()
    );
    let TokenImage = TokenMetadata.image;
    if (TokenImage.startsWith("ipfs://")) {
      TokenImage = `https://w3s.link/ipfs/${TokenImage.split("ipfs://")[1]}`;
    }
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
      <div className="card-body py-2">
        <div className="flex flex-row justify-around items-center">
          <div className="flex justify-around items-center gap-2">
            <h2 className="card-title">
              <Link href={`/space/${props.id}`}>
                #{props.id < 10 && "0"}
                {props.id}
              </Link>
            </h2>
            <div className="badge badge-primary">
              {props.exists ? "CLAIMED" : "UNCLAIMED"}
            </div>
          </div>

          <div className="flex justify-between items-center">
            <div
              className="badge border-0 tooltip flex"
              data-tip={`${ethers.utils.formatEther(
                props.highestOffer.toString()
              )}`}
            >
              {Number(props.highestOffer) > 0 ? (
                <Image
                  className="w-7 pr-1"
                  src={purpleOffer}
                  alt={`${ethers.utils.formatEther(
                    props.highestOffer.toString()
                  )}`}
                />
              ) : (
                <Image
                  className="w-7 pr-1"
                  src={grayOffer}
                  alt={`${ethers.utils.formatEther(
                    props.highestOffer.toString()
                  )}`}
                />
              )}
              {/* <Image
              className="w-7 pr-1"
              src={grayOffer}
              alt={`${ethers.utils.formatEther(props.highestOffer.toString())}`}
            /> */}
              {/* {ethers.utils.formatEther(props.highestOffer.toString())} */}
            </div>

            <div
              className="badge border-0 tooltip flex"
              data-tip={`${
                Number(props.balance) > 0
                  ? Number(
                      ethers.utils.formatEther(props.balance.toString())
                    ).toFixed(8)
                  : ethers.utils.formatEther(props.balance.toString())
              }`}
            >
              {Number(props.balance) > 0 ? (
                <Image className="w-7 pr-1" src={purpleBalance} alt="balance" />
              ) : (
                <Image className="w-7 pr-1" src={grayBalance} alt="balance" />
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
