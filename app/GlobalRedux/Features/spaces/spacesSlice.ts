"use client";

import { createAsyncThunk, createSlice, PayloadAction } from "@reduxjs/toolkit";
import { BigNumber, ethers } from "ethers";
import { spaceMarketplaceAddress } from "../../../../components/Config/Config";

const spaceABI = require("../../../../components/ABI/spaceABI.json");

export interface Space {
  spaceNo: string;
  exists: boolean;
  owner: string;
  balance: string;
  highestOffer: string;
  highestOfferer: string;
  spaceUri: string;
  subscTime: string;
  subscBurn: string;
  subscOffer: string;
}

interface SpaceState {
  spaces: Space[];
}

const initialState: SpaceState = {
  spaces: [],
};

export const fetchSpaces = createAsyncThunk("spaces/fetch", async () => {
  const provider = new ethers.providers.JsonRpcProvider(
    "https://polygon-mumbai.g.alchemy.com/v2/2TI0SeKoUJzCRBNaFnTGaV9B7uvkxnsy"
  );

  const spaceContract = new ethers.Contract(
    spaceMarketplaceAddress,
    spaceABI,
    provider
  );

  const Spaces = await spaceContract.getAllClaimedSpaces();

  return Spaces;
});

export const SpaceSlice = createSlice({
  name: "space",
  initialState,
  reducers: {},
  extraReducers: (builder) => {
    builder.addCase(fetchSpaces.fulfilled, (state, action) => {
      state.spaces = action.payload;
    });
  },
});
