import Space from "@/components/Space/Space";
import { Suspense } from "react";

export default function Home() {
  return (
    <main className="">
      <Suspense
        fallback={<p className="text-5xl font-bold">Loading Spaces...</p>}
      >
        <Space />
      </Suspense>
    </main>
  );
}
