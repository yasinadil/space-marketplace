import React from "react";
import Image from "next/image";
import space from "../../public/assets/space.png";
import Link from "next/link";
import polygon from "../../public/assets/polygon.png";
import offer from "../../public/assets/offer.png";
import { ethers } from "ethers";

export default function SpaceCard(props: any) {
  return (
    <div className="card object-cover w-[100%] h-[100%] bg-base-100 shadow-xl">
      <figure className="cursor-pointer">
        <Link href={`/space/${props.id}`}>
          <Image src={space} alt="Shoes" />
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
            {ethers.utils.formatEther(props.balance.toString())}
          </div>
          <div className="badge border-0 tooltip flex" data-tip="balance">
            <Image className="w-7 pr-1" src={polygon} alt="balance" />
            {ethers.utils.formatEther(props.highestOffer.toString())}
          </div>
        </div>
      </div>
    </div>
  );
}
