"use client";
import React from "react";
import { useParams } from "next/navigation";
import { useState, useEffect } from "react";
import spaceImg from "../../../public/assets/space.png";
import Image from "next/image";
import { ethers } from "ethers";
import goBack from "../../../public/assets/go-back.png";
import Link from "next/link";
import { Web3Button } from "@thirdweb-dev/react";
import { spaceMarketplaceAddress, WETH } from "@/components/Config/Config";
import { ToastContainer, toast } from "react-toastify";
import { useAddress } from "@thirdweb-dev/react";
import truncateEthAddress from "truncate-eth-address";
import "react-toastify/dist/ReactToastify.css";

const spaceABI = require("../../../components/ABI/spaceABI.json");
const WETHABI = require("../../../components/ABI/WETHABI.json");

export interface Space {
  exists: boolean;
  owner: string;
  balance: string;
  highestOffer: string;
  highestOfferer: string;
  spaceUri: string;
}

export default function Page() {
  const params = useParams();
  const address = useAddress();

  let spaceID = params.id;

  const [exists, setSpaceExists] = useState("loading...");
  const [owner, setSpaceOwner] = useState("loading...");
  const [balance, setSpaceBalance] = useState("0");
  const [highestOffer, setSpaceHighestOffer] = useState("0");
  const [highestOfferer, setSpaceHighestOfferer] = useState("loading...");
  const [spaceUri, setSpaceUri] = useState("loading...");

  const [depositBalance, setDepositBalance] = useState("");
  const [withdrawAmount, setWithdrawAmount] = useState("");
  const [amount, setAmount] = useState("");
  const [offerAmount, setOfferAmount] = useState("");
  const [subsOffer, setSubsOffer] = useState("");
  const [newOwner, setNewOwner] = useState("");

  const [depositBalanceApproved, isDepositBalanceApproved] = useState(false);
  const [makeOfferApproved, isMakeOfferApproved] = useState(false);
  const [approved, isApproved] = useState(false);

  const [tokenId, setTokenId] = useState("");
  const [contractAddress, setContractAddress] = useState("");

  useEffect(() => {
    async function loadSpace() {
      const provider = new ethers.providers.JsonRpcProvider(
        "https://polygon-mumbai.g.alchemy.com/v2/2TI0SeKoUJzCRBNaFnTGaV9B7uvkxnsy"
      );

      const spaceContract = new ethers.Contract(
        spaceMarketplaceAddress,
        spaceABI,
        provider
      );

      const currSpace = await spaceContract.spaces(Number(spaceID));
      console.log(currSpace);
      console.log(currSpace.exists);

      if (currSpace.exists) {
        const exists = currSpace.exists;
        const spaceNo = currSpace.spaceNo;

        const owner = currSpace.owner;
        const balance = ethers.utils.formatEther(currSpace.balance.toString());
        const highestOffer = ethers.utils.formatEther(
          currSpace.highestOffer.toString()
        );
        let highestOfferer = currSpace.highestOfferer;
        if (highestOfferer == "0x0000000000000000000000000000000000000000") {
          highestOfferer = "None";
        }
        let spaceUri = currSpace.spaceUri;
        console.log("Setting");
        if (spaceUri != "") {
          spaceUri = `https://w3s.link/ipfs/${spaceUri.split("ipfs://")[1]}`;

          const TokenMetadata = await fetch(spaceUri).then((response) =>
            response.json()
          );
          let TokenImage = TokenMetadata.image;
          if (TokenImage.startsWith("ipfs://")) {
            TokenImage = `https://w3s.link/ipfs/${
              TokenImage.split("ipfs://")[1]
            }`;
          }
          spaceUri = TokenImage;
        }

        setSpaceExists("claimed");
        setSpaceOwner(owner);
        setSpaceBalance(balance);
        setSpaceHighestOffer(highestOffer);
        setSpaceHighestOfferer(highestOfferer);
        if (spaceUri == "") {
          setSpaceUri("nothing");
        } else {
          setSpaceUri(spaceUri);
        }
      } else {
        setSpaceExists("unclaimed");
        setSpaceOwner("unowned");
        setSpaceBalance("0");
        setSpaceHighestOffer("0");
        setSpaceHighestOfferer("None");
        setSpaceUri("nothing");
      }
    }

    loadSpace();
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
          Space #{Number(spaceID) < 10 && "0"}
          {spaceID}
        </h1>
        <div className="flex flex-col gap-y-4">
          <div className="h-[300px]">
            {spaceUri == "loading..." && (
              <div className="animate-pulse flex space-x-4">
                <div className="rounded-lg bg-slate-700 w-[300px] h-[300px]"></div>
              </div>
            )}

            {spaceUri == "nothing" && (
              <Image
                className="w-[300px] xl:w-[700px] h-[300px] rounded-2xl"
                src={spaceImg}
                alt="spaceImage"
              />
            )}

            {spaceUri != "nothing" && spaceUri != "loading..." && (
              <img
                className="max-w-[300px] max-h-[300px]"
                src={spaceUri}
                alt="spaceImage"
              />
            )}
          </div>

          <div className="flex flex-col gap-y-4 my-5">
            <div className="border-b border-black pb-2 flex justify-between">
              {" "}
              <h1 className="text-lg w-44 p-1 text-black rounded-xl text-left">
                Status
              </h1>
              <h1 className="font-semibold">{exists}</h1>
            </div>

            <div className="flex justify-between border-b border-black pb-2">
              {" "}
              <h1 className="text-lg w-44 p-1 text-black rounded-xl text-left">
                Owner
              </h1>
              {exists ? (
                <h1 className="font-semibold block md:hidden">
                  {" "}
                  {truncateEthAddress(owner)}
                </h1>
              ) : (
                <h1 className="font-semibold block md:hidden"> {owner}</h1>
              )}
              <h1 className="font-semibold hidden md:block"> {owner}</h1>
            </div>
            <div className="flex justify-between border-b border-black pb-2">
              {" "}
              <h1 className="text-lg w-44 p-1 text-black rounded-xl text-left">
                Balance
              </h1>
              <h1 className="font-semibold">{balance} MATIC</h1>
            </div>

            <div className="flex justify-between border-b border-black pb-2">
              {" "}
              <h1 className="text-lg w-44 p-1 text-black rounded-xl text-left">
                Highest Offer
              </h1>
              <h1 className="font-semibold">{highestOffer} MATIC</h1>
            </div>

            <div className="flex justify-between">
              <h1 className="text-lg w-44 p-1 text-black rounded-xl text-left">
                Highest Offerer
              </h1>
              {highestOfferer != "None" && (
                <h1 className="font-semibold block md:hidden">
                  {truncateEthAddress(highestOfferer)}
                </h1>
              )}
              <h1 className="font-semibold hidden md:block">
                {highestOfferer}
              </h1>
            </div>
          </div>
          <div>
            <h1 className="text-2xl font-bold">Actions</h1>
            {exists == "unclaimed" && (
              <div className="my-5">
                <h1 className="pl-2 pb-1">Claim Space</h1>
                <div className="join">
                  <input
                    className="input input-bordered join-item w-[200px]"
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
                      onSuccess={() => {
                        toast.success("Successfully claimed your space!", {
                          position: "top-center",
                          autoClose: 5000,
                          hideProgressBar: false,
                          closeOnClick: true,
                          pauseOnHover: true,
                          draggable: true,
                          progress: undefined,
                          theme: "dark",
                        });
                        setSpaceExists("claimed");
                        setSpaceOwner(address!);
                        setSpaceBalance(amount);
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

            {owner == address && (
              <div className="my-5">
                <h1 className="pl-2 pb-1">Deposit Balance</h1>
                <div className="join">
                  <input
                    className="input input-bordered join-item"
                    placeholder="Balance"
                    onChange={(event) => setDepositBalance(event.target.value)}
                  />
                  {depositBalanceApproved ? (
                    <Web3Button
                      contractAddress={spaceMarketplaceAddress}
                      contractAbi={spaceABI}
                      theme="dark"
                      // Call the name of your smart contract function
                      action={(contract) =>
                        contract.call("deposit", [
                          spaceID,
                          ethers.utils.parseEther(depositBalance),
                        ])
                      }
                      onSuccess={() => {
                        toast.success(
                          `Successfully deposited ${ethers.utils.parseEther(
                            depositBalance
                          )}`,
                          {
                            position: "top-center",
                            autoClose: 5000,
                            hideProgressBar: false,
                            closeOnClick: true,
                            pauseOnHover: true,
                            draggable: true,
                            progress: undefined,
                            theme: "dark",
                          }
                        );
                        setSpaceBalance(
                          (Number(balance) + Number(depositBalance)).toString()
                        );
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
                        DEPOSIT
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
                          ethers.utils.parseEther(depositBalance),
                        ])
                      }
                      onSuccess={() => {
                        toast.success("Approved WETH", {
                          position: "top-center",
                          autoClose: 5000,
                          hideProgressBar: false,
                          closeOnClick: true,
                          pauseOnHover: true,
                          draggable: true,
                          progress: undefined,
                          theme: "dark",
                        });
                        isDepositBalanceApproved(true);
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

            {owner == address && (
              <div className="my-5">
                <h1 className="pl-2 pb-1">Transfer Space</h1>
                <div className="join">
                  <input
                    className="input input-bordered join-item"
                    placeholder="Wallet Address"
                    onChange={(event) => setNewOwner(event.target.value)}
                  />

                  <Web3Button
                    contractAddress={spaceMarketplaceAddress}
                    contractAbi={spaceABI}
                    theme="dark"
                    // Call the name of your smart contract function
                    action={(contract) =>
                      contract.call("transferSpace", [spaceID, newOwner])
                    }
                    onSuccess={() =>
                      toast.success("Space Transferred", {
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
                      TRANSFER
                    </span>
                  </Web3Button>
                </div>
              </div>
            )}

            {owner == address && (
              <div className="my-5">
                <h1 className="pl-2 pb-1">Withdraw Balance</h1>
                <div className="join">
                  <input
                    className="input input-bordered join-item"
                    placeholder="Amount"
                    onChange={(event) => setWithdrawAmount(event.target.value)}
                  />

                  <Web3Button
                    contractAddress={spaceMarketplaceAddress}
                    contractAbi={spaceABI}
                    theme="dark"
                    // Call the name of your smart contract function
                    action={(contract) =>
                      contract.call("withdraw", [
                        spaceID,
                        ethers.utils.parseEther(withdrawAmount),
                      ])
                    }
                    onSuccess={() =>
                      toast.success("Offer Retracted", {
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
                      WITHDRAW
                    </span>
                  </Web3Button>
                </div>
              </div>
            )}

            <div className="my-5">
              <h1 className="pl-2 pb-1">Make Offer</h1>
              <input
                className="input input-bordered join-item w-[150px] block md:hidden"
                placeholder="Offer"
                onChange={(event) => setOfferAmount(event.target.value)}
              />
              <div className="join">
                <input
                  className="input input-bordered join-item w-[150px] hidden md:block"
                  placeholder="Offer"
                  onChange={(event) => setOfferAmount(event.target.value)}
                />
                <input
                  className="input input-bordered join-item w-[200px]"
                  placeholder="Subsciption Offer"
                  onChange={(event) => setSubsOffer(event.target.value)}
                />
                {makeOfferApproved ? (
                  <Web3Button
                    contractAddress={spaceMarketplaceAddress}
                    contractAbi={spaceABI}
                    theme="dark"
                    // Call the name of your smart contract function
                    action={(contract) =>
                      contract.call("offer", [
                        spaceID,
                        ethers.utils.parseEther(offerAmount),
                        ethers.utils.parseEther(subsOffer),
                      ])
                    }
                    onSuccess={() => {
                      toast.success("Offer Made", {
                        position: "top-center",
                        autoClose: 5000,
                        hideProgressBar: false,
                        closeOnClick: true,
                        pauseOnHover: true,
                        draggable: true,
                        progress: undefined,
                        theme: "dark",
                      });
                      setSpaceHighestOfferer(address!);
                      setSpaceHighestOffer(offerAmount);
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
                    <span className="btn join-item rounded-r-full">OFFER</span>
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
                        ethers.utils.parseEther(
                          (Number(offerAmount) + Number(subsOffer)).toString()
                        ),
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
                      isMakeOfferApproved(true);
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

            {owner == address && (
              <div className="my-5 w-[100%]">
                <h1 className="pl-2 pb-1">Set NFT for Space</h1>

                <input
                  className="input input-bordered join-item block md:hidden"
                  placeholder="Contract Address"
                  onChange={(event) => setContractAddress(event.target.value)}
                />

                <div className="join">
                  <input
                    className="input input-bordered join-item w-[190px] hidden md:block"
                    placeholder="Contract Address"
                    onChange={(event) => setContractAddress(event.target.value)}
                  />
                  <input
                    className="input input-bordered join-item w-[200px]"
                    placeholder="Token ID"
                    onChange={(event) => setTokenId(event.target.value)}
                  />

                  <Web3Button
                    contractAddress={spaceMarketplaceAddress}
                    contractAbi={spaceABI}
                    theme="dark"
                    // Call the name of your smart contract function
                    action={(contract) =>
                      contract.call("setSpaceUri", [
                        spaceID,
                        tokenId,
                        contractAddress,
                      ])
                    }
                    onSuccess={() =>
                      toast.success("Changed NFT to display on Space", {
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
                    <span className="btn join-item rounded-r-full">SET</span>
                  </Web3Button>
                </div>
              </div>
            )}

            <div className="my-5">
              <h1 className="pl-2 pb-1">Accept Offer</h1>

              <Web3Button
                contractAddress={spaceMarketplaceAddress}
                contractAbi={spaceABI}
                theme="dark"
                // Call the name of your smart contract function
                action={(contract) => contract.call("acceptOffer", [spaceID])}
                onSuccess={() =>
                  toast.success("Offer Accepted", {
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
                <span className="btn join-item rounded-r-full">ACCEPT</span>
              </Web3Button>
            </div>

            <div className="my-5">
              <h1 className="pl-2 pb-1">Retract Offer</h1>

              <Web3Button
                contractAddress={spaceMarketplaceAddress}
                contractAbi={spaceABI}
                theme="dark"
                // Call the name of your smart contract function
                action={(contract) => contract.call("retractOffer", [spaceID])}
                onSuccess={() =>
                  toast.success("Offer Retracted", {
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
                <span className="btn join-item rounded-r-full">RETRACT</span>
              </Web3Button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
