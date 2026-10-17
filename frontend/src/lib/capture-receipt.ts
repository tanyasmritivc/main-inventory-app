/** Remove drafts only when indexed receipts establish that they were saved. */
export function confirmedCaptureIndices(result: {
  inserted: unknown[];
  failures: Array<Record<string, unknown>>;
  accepted_indices?: number[];
}, submittedCount: number): Set<number> {
  const indices = result.accepted_indices;
  if (indices === undefined) {
    return result.failures.length === 0 && result.inserted.length === submittedCount
      ? new Set(Array.from({ length: submittedCount }, (_, index) => index))
      : new Set();
  }
  if (!Array.isArray(indices)) throw new Error("Saving could not be confirmed. Your draft is safe to retry.");
  const accepted = new Set(indices);
  if (accepted.size !== indices.length || accepted.size !== result.inserted.length ||
      indices.some(index => !Number.isSafeInteger(index) || index < 0 || index >= submittedCount) ||
      result.failures.some(failure => accepted.has(failure.index as number))) {
    throw new Error("Saving could not be confirmed. Your draft is safe to retry.");
  }
  return accepted;
}
