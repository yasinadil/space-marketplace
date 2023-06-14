"use client";
import Space from "@/components/Space/Space";
import { Suspense } from "react";
import { useEffect } from "react";
import { fetchSpaces } from "@/app/GlobalRedux/Features/spaces/spacesSlice";
import { useAppDispatch } from "./GlobalRedux/store";

export default function Home() {
  const dispatch = useAppDispatch();
  useEffect(() => {
    dispatch(fetchSpaces());
  }, []);
  return (
    <main className="">
      <Suspense fallback={<p>Loading Spaces...</p>}>
        {/* @ts-expect-error Server Component */}
        <Space />
      </Suspense>
    </main>
  );
}
