import { confirmedCaptureIndices } from "@/lib/capture-receipt";

test("only explicit saved indices can remove partial drafts", () => {
  expect([...confirmedCaptureIndices({ inserted: [{}], accepted_indices: [1], failures: [{ index: 0 }] }, 2)]).toEqual([1]);
  expect([...confirmedCaptureIndices({ inserted: [{}], failures: [{ index: 0 }] }, 2)]).toEqual([]);
  expect([...confirmedCaptureIndices({ inserted: [{}, {}], failures: [] }, 2)]).toEqual([0, 1]);
});

test.each([[0, 0], [-1], [2], [0.5], [0, 1]].map(indices => [indices]))("invalid receipt %j keeps drafts safe", indices => {
  expect(() => confirmedCaptureIndices({ inserted: [{}], accepted_indices: indices, failures: [] }, 2)).toThrow("could not be confirmed");
});

test("an index cannot be both saved and failed", () => {
  expect(() => confirmedCaptureIndices({ inserted: [{}], accepted_indices: [0], failures: [{ index: 0 }] }, 1)).toThrow();
});
