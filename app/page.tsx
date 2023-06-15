import Space from "@/components/Space/Space";
import { Suspense } from "react";

export default function Home() {
  return (
    <main className="">
      <Suspense
        fallback={
          <div className="flex justify-center items-center min-h-screen">
            <span className="loading loading-dots loading-lg"></span>
          </div>
        }
      >
        <Space />
      </Suspense>
    </main>
  );
}
