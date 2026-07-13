import { departSession } from "@/lib/identity/signin";
import { NextResponse } from "next/server";

/** POST /api/identity/depart — "this isn't my device." Leaves nothing behind. */
export async function POST() {
  await departSession();
  return NextResponse.json({ message: "Nothing of your story remains here." });
}
