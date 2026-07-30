// Regions that stay normally interactive in comment mode: a click there means
// what it normally means, not "comment here".
export const EXEMPT = "[data-comment-toolbar], .anchor-strip, [data-comment-exempt], [data-comment-form]"

export function isExempt(target) {
  return Boolean(target.closest && target.closest(EXEMPT))
}
