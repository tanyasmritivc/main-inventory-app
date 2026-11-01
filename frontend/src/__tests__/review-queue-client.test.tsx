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

test("opens a compact row to inspect the capture and evidence", async () => {
  const user = userEvent.setup();
  render(<ReviewQueueClient />);

  const row = await screen.findByRole("button", { name: `Review ${review.name}` });
  expect(row.getAttribute("aria-expanded")).toBe("false");
  expect(screen.queryByLabelText("Name")).toBeNull();
  await user.click(row);
  await user.click(screen.getByText("Capture information", { selector: "summary" }));
  expect(screen.getByRole("img", { name: `Captured ${review.name}` }).getAttribute("src")).toBe(review.image_url);
  expect(screen.getAllByText("The identification confidence is low.")).toHaveLength(2);
  expect(screen.getByText("Visible shape and markings suggest a fastener.")).toBeTruthy();
  expect(screen.getByText("M4")).toBeTruthy();
  expect(screen.getByText("CODE_128")).toBeTruthy();
  expect(screen.getByText("20.0 × 4.0 mm")).toBeTruthy();
  expect(screen.getByText("Only part of the photo analysis completed.")).toBeTruthy();
});

test("confirms a reviewed item and removes it from the queue", async () => {
  const user = userEvent.setup();
  render(<ReviewQueueClient />);

  await user.click(await screen.findByRole("button", { name: `Review ${review.name}` }));
  await user.click(screen.getByRole("button", { name: "Confirm and save" }));

  await waitFor(() => expect(api.resolveReviewItem).toHaveBeenCalledWith({
    token: "web-token",
    reviewId: "review-1",
    item: expect.objectContaining({ location: "Drawer A", name: review.name }),
  }));
  expect(await screen.findByText(`${review.name} was saved to your inventory.`)).toBeTruthy();
  expect(screen.queryByRole("button", { name: `Review ${review.name}` })).toBeNull();
});


test("bounds large queues to 25 rows and keeps edits when switching items and pages", async () => {
  const user = userEvent.setup();
  jest.mocked(api.getReviewItems).mockResolvedValue({
    items: Array.from({ length: 100 }, (_, i) => ({ ...review, review_id: `review-${i}`, name: `Capture ${i}` })),
    pending_count: 250,
  });
  render(<ReviewQueueClient />);
  await screen.findByRole("button", { name: "Review Capture 0" });
  expect(screen.getAllByRole("button", { name: /^Review Capture/ })).toHaveLength(25);
  expect(screen.getByText("250 pending · 1–25 shown")).toBeTruthy();
  expect(screen.getByText(/Showing the latest 100 captures/)).toBeTruthy();
  await user.click(screen.getByRole("button", { name: "Review Capture 0" }));
  await user.clear(screen.getByLabelText("Brand"));
  await user.type(screen.getByLabelText("Brand"), "Corrected brand");
  await user.click(screen.getByRole("button", { name: "Review Capture 1" }));
  expect(screen.getAllByLabelText("Name")).toHaveLength(1);
  await user.click(screen.getByRole("button", { name: "Next" }));
  expect(screen.queryByRole("button", { name: "Review Capture 0" })).toBeNull();
  expect(screen.getByRole("button", { name: "Review Capture 25" })).toBeTruthy();
  await user.click(screen.getByRole("button", { name: "Previous" }));
  await user.click(screen.getByRole("button", { name: "Review Capture 0" }));
  expect((screen.getByLabelText("Brand") as HTMLInputElement).value).toBe("Corrected brand");
  expect(api.resolveReviewItem).not.toHaveBeenCalled();
});

test("keeps the open correction and draft after a failed save", async () => {
  const user = userEvent.setup();
  jest.mocked(api.resolveReviewItem).mockRejectedValueOnce(new Error("Request failed"));
  render(<ReviewQueueClient />);
  await user.click(await screen.findByRole("button", { name: `Review ${review.name}` }));
  await user.type(screen.getByLabelText("Notes"), "Check the head size");
  await user.click(screen.getByRole("button", { name: "Confirm and save" }));
  await waitFor(() => expect(api.resolveReviewItem).toHaveBeenCalled());
  expect((screen.getByLabelText("Notes") as HTMLTextAreaElement).value).toBe("Check the head size");
  expect(screen.getByRole("button", { name: `Review ${review.name}` }).getAttribute("aria-expanded")).toBe("true");
});
