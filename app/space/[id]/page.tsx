"use client";
import React from "react";
import { useState, useEffect } from "react";
import { useAppSelector } from "@/app/GlobalRedux/store";
import spaceImg from "../../../public/assets/space.png";
import Image from "next/image";
import { ethers } from "ethers";
import goBack from "../../../public/assets/go-back.png";
import Link from "next/link";
import { Web3Button } from "@thirdweb-dev/react";
import { spaceMarketplaceAddress, WETH } from "@/components/Config/Config";
import { ToastContainer, toast } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";

const spaceABI = require("../../../components/ABI/spaceABI.json");
const WETHABI = require("../../../components/ABI/WETHABI.json");

export default async function Page({ params }: any) {
  const space = useAppSelector((state) => state.spaces.spaces);
  let spaceID = Number(params.id) - 1;
  let url = space[spaceID].spaceUri;

  const [nft, setNft] = useState("");
  const [amount, setAmount] = useState("");
  const [approved, isApproved] = useState(false);

  useEffect(() => {
    async function loadImage() {
      if (url != "") {
        url = `https://w3s.link/ipfs/${url.split("ipfs://")[1]}`;

        const TokenMetadata = await fetch(url).then((response) =>
          response.json()
        );
        let TokenImage = TokenMetadata.image;
        // if (TokenImage.startsWith("ipfs://")) {
        //   TokenImage = `https://w3s.link/ipfs/${
        //     TokenImage.split("ipfs://")[1]
        //   }`;
        // }
        setNft(TokenImage);
      }
    }
    if (url != "") {
      loadImage();
    }
  }, []);

  return (
    <div className="mx-10 my-12 flex justify-center">
      <ToastContainer
        position="top-center"
        autoClose={5000}
        hideProgressBar={false}
        newestOnTop={false}
        closeOnClick
        rtl={false}
        pauseOnFocusLoss
        draggable
        pauseOnHover
        theme="dark"
      />
      <div>
        <div className="mb-4 w-10 cursor-pointer">
          <Link className="" href={"/"}>
            <Image className="" src={goBack} alt="back" />
          </Link>
        </div>

        <h1 className="font-semibold text-2xl mb-6">
          Space #{params.id < 10 && "0"}
          {params.id}
        </h1>
        <div className="flex flex-col gap-y-4">
          {url != "" ? (
            <img className="w-[300px]" src={nft} alt="spaceImage" />
          ) : (
            <Image
              className="w-[300px] xl:w-[700px] rounded-2xl"
              src={spaceImg}
              alt="spaceImage"
            />
          )}
          <div className="flex flex-col gap-y-4 my-5">
            <div className="border-b border-black pb-2 flex justify-between">
              {" "}
              <h1 className="text-lg w-44 p-1 text-black rounded-xl text-left">
                Status
              </h1>
              <h1 className="font-semibold">
                {space[spaceID].exists ? "claimed" : "unclaimed"}
              </h1>
            </div>

            <div className="flex justify-between border-b border-black pb-2">
              {" "}
              <h1 className="text-lg w-44 p-1 text-black rounded-xl text-left">
                Owner
              </h1>
              <h1 className="font-semibold">
                {" "}
                {space[spaceID].exists ? space[spaceID].owner : "unowned"}
              </h1>
            </div>
            <div className="flex justify-between border-b border-black pb-2">
              {" "}
              <h1 className="text-lg w-44 p-1 text-black rounded-xl text-left">
                Balance
              </h1>
              <h1 className="font-semibold">
                {ethers.utils.formatEther(space[spaceID].balance.toString())}{" "}
                MATIC
              </h1>
            </div>

            <div className="flex justify-between border-b border-black pb-2">
              {" "}
              <h1 className="text-lg w-44 p-1 text-black rounded-xl text-left">
                Highest Offer
              </h1>
              <h1 className="font-semibold">
                {ethers.utils.formatEther(
                  space[spaceID].highestOffer.toString()
                )}{" "}
                MATIC
              </h1>
            </div>

            <div className="flex justify-between">
              <h1 className="text-lg w-44 p-1 text-black rounded-xl text-left">
                Highest Offerer
              </h1>
              <h1 className="font-semibold">
                {space[spaceID].highestOfferer !=
                "0x0000000000000000000000000000000000000000"
                  ? space[spaceID].highestOfferer
                  : "None"}
              </h1>
            </div>
          </div>
          <div>
            <h1 className="text-2xl font-bold">Actions</h1>
            {!space[spaceID].exists && (
              <div className="my-5">
                <h1 className="pl-2 pb-1">Claim Space</h1>
                <div className="join">
                  <input
                    className="input input-bordered join-item"
                    placeholder="Deposit"
                    onChange={(event) => setAmount(event?.target.value)}
                  />
                  {approved ? (
                    <Web3Button
                      contractAddress={spaceMarketplaceAddress}
                      contractAbi={spaceABI}
                      theme="dark"
                      // Call the name of your smart contract function
                      action={(contract) =>
                        contract.call("claimSpace", [
                          spaceID,
                          ethers.utils.parseEther(amount),
                        ])
                      }
                      onSuccess={() =>
                        toast.success("Successfully claimed your space!", {
                          position: "top-center",
                          autoClose: 5000,
                          hideProgressBar: false,
                          closeOnClick: true,
                          pauseOnHover: true,
                          draggable: true,
                          progress: undefined,
                          theme: "dark",
                        })
                      }
                      onError={(error: any) =>
                        toast.error(error.reason, {
                          position: "top-center",
                          autoClose: 5000,
                          hideProgressBar: false,
                          closeOnClick: true,
                          pauseOnHover: true,
                          draggable: true,
                          progress: undefined,
                          theme: "dark",
                        })
                      }
                    >
                      <span className="btn join-item rounded-r-full">
                        CLAIM
                      </span>
                    </Web3Button>
                  ) : (
                    <Web3Button
                      contractAddress={WETH}
                      contractAbi={WETHABI}
                      theme="dark"
                      // Call the name of your smart contract function
                      action={(contract) =>
                        contract.call("approve", [
                          spaceMarketplaceAddress,
                          ethers.utils.parseEther(amount),
                        ])
                      }
                      onSuccess={() => {
                        toast.success("Approved WETH!", {
                          position: "top-center",
                          autoClose: 5000,
                          hideProgressBar: false,
                          closeOnClick: true,
                          pauseOnHover: true,
                          draggable: true,
                          progress: undefined,
                          theme: "dark",
                        });
                        isApproved(true);
                      }}
                      onError={(error: any) =>
                        toast.error(error.reason, {
                          position: "top-center",
                          autoClose: 5000,
                          hideProgressBar: false,
                          closeOnClick: true,
                          pauseOnHover: true,
                          draggable: true,
                          progress: undefined,
                          theme: "dark",
                        })
                      }
                    >
                      <span className="btn join-item rounded-r-full">
                        APPROVE
                      </span>
                    </Web3Button>
                  )}
                </div>
              </div>
            )}

            <div className="my-5">
              <h1 className="pl-2 pb-1">Make Offer</h1>
              <div className="join">
                <input
                  className="input input-bordered join-item"
                  placeholder="Deposit"
                />
                <button className="btn join-item rounded-r-full">OFFER</button>
              </div>
            </div>

            <div className="my-5">
              <h1 className="pl-2 pb-1">Accept Offer</h1>
              <div className="join">
                <input
                  className="input input-bordered join-item"
                  placeholder="Deposit"
                />
                <button className="btn join-item rounded-r-full">ACCEPT</button>
              </div>
            </div>

            <div className="my-5">
              <h1 className="pl-2 pb-1">Transfer Space</h1>
              <div className="join">
                <input
                  className="input input-bordered join-item"
                  placeholder="Wallet Address"
                />
                <button className="btn join-item rounded-r-full">
                  TRANSFER
                </button>
              </div>
            </div>

            <div className="my-5 w-[100%]">
              <h1 className="pl-2 pb-1">Set NFT for Space</h1>

              <input
                className="input input-bordered join-item block md:hidden"
                placeholder="Contract Address"
              />

              <br />
              <div className="join">
                <input
                  className="input input-bordered join-item hidden md:block"
                  placeholder="Contract Address"
                />
                <input
                  className="input input-bordered join-item"
                  placeholder="Token ID"
                />
                <button className="btn join-item rounded-r-full">SET</button>
              </div>
            </div>

            <div className="my-5">
              <h1 className="pl-2 pb-1">Retract Offer</h1>

              <button className="btn rounded-lg">RETRACT</button>
            </div>

            <div className="my-5">
              <h1 className="pl-2 pb-1">Withdraw Balance</h1>

              <button className="btn join-item rounded-lg">WITHDRAW</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
