import { ThresholdExperience } from "@/components/threshold/ThresholdExperience";

// Variant B — Presence (experiment archive).
//
// A/B/C are no longer competing alternatives. As of 2026-08-03 the canonical
// threshold experience lives at / (OpeningExperience → ThresholdScreen).
// These routes are retained for historical reference and ongoing instrumented
// study, but the product threshold is ThresholdScreen, not this component.
export default function Page() {
  return <ThresholdExperience variant="b" />;
}
