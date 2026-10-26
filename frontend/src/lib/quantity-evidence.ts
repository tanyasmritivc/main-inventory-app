export function hasUnknownQuantity(evidence?: {quantity_basis?: string | null; review_reasons?: string[]} | null) {
  return evidence?.quantity_basis !== 'user_confirmed' && (evidence?.quantity_basis === 'unknown' || !!evidence?.review_reasons?.some((reason) => reason.includes('Quantity is a candidate placeholder')));
}
