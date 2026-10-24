/** @jest-environment jsdom */

import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import { ReviewQueueClient } from "@/components/site/review-queue-client";
import * as api from "@/lib/api";
import { useApiSession } from "@/lib/use-api-session";

jest.mock("@/lib/use-api-session");
jest.mock("@/lib/api", () => ({
  ...jest.requireActual("@/lib/api"),
  getReviewItems: jest.fn(),
  resolveReviewItem: jest.fn(),
  dismissReviewItem: jest.fn(),
}));
const confirmAction = jest.fn();
jest.mock("@/components/site/app-dialog-provider", () => ({
  useAppDialog: () => ({ confirmAction }),
}));

const review: api.ReviewItem = {
  review_id: "review-1",
  status: "pending",
  source_kind: "photo_scan",
  created_at: "2026-09-29T12:00:00Z",
  name: "Unidentified fastener",
  category: "Hardware",
  quantity: 2,
  location: "Drawer A",
  image_url: "https://images.test/fastener.jpg",
  barcode: "12345",
  scan_evidence: {
    needs_review: true,
    identity_confidence: 0.42,
    detection_confidence: 0.88,
    identification_reasoning: "Visible shape and markings suggest a fastener.",
    ocr_text: "M4",
    ocr_confidence: 0.76,
    length_mm: 20,
    width_mm: 4,
    measurement_method: "ruler",
    measurement_confidence: "medium",
    measurement_assumption: "The item and ruler appear to share a plane.",
    barcode_symbology: "CODE_128",
    barcode_confidence: 0.91,
    review_reasons: ["The identification confidence is low."],
    warnings: ["Only part of the photo analysis completed."],
  },
};

beforeEach(() => {
  jest.clearAllMocks();
  jest.mocked(useApiSession).mockReturnValue({
    token: "web-token",
    loading: false,
    error: null,
  } as ReturnType<typeof useApiSession>);
  jest.mocked(api.getReviewItems).mockResolvedValue({
    items: [review],
    pending_count: 1,
  });
  jest.mocked(api.resolveReviewItem).mockResolvedValue({
    item: {
      item_id: "item-1",
      name: review.name,
      category: review.category,
      quantity: review.quantity,
      location: review.location!,
      created_at: review.created_at,
    },
  });
  confirmAction.mockResolvedValue(true);
});

test("shows the capture image and every user-facing evidence group", async () => {
  render(<ReviewQueueClient />);

  expect(await screen.findByRole("heading", { name: review.name })).toBeTruthy();
  expect(screen.getByRole("img", { name: `Captured ${review.name}` }).getAttribute("src")).toBe(review.image_url);
  expect(screen.getByText("The identification confidence is low.")).toBeTruthy();
  expect(screen.getByText("Visible shape and markings suggest a fastener.")).toBeTruthy();
  expect(screen.getByText("M4")).toBeTruthy();
  expect(screen.getByText("CODE_128")).toBeTruthy();
  expect(screen.getByText("20.0 × 4.0 mm")).toBeTruthy();
  expect(screen.getByText("Only part of the photo analysis completed.")).toBeTruthy();
});

test("confirms a reviewed item and removes it from the queue", async () => {
  const user = userEvent.setup();
  render(<ReviewQueueClient />);

  await user.click(await screen.findByRole("button", { name: "Confirm and add to Find" }));

  await waitFor(() => expect(api.resolveReviewItem).toHaveBeenCalledWith({
    token: "web-token",
    reviewId: "review-1",
    item: expect.objectContaining({ location: "Drawer A", name: review.name }),
  }));
  expect(await screen.findByText(`${review.name} was confirmed and added to Find.`)).toBeTruthy();
  expect(screen.queryByRole("heading", { name: review.name })).toBeNull();
});
