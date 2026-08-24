// Every card in the editor clips its overflow to keep its rounded corners, so a
// panel positioned inside one gets cut off. A popover lives in the top layer,
// which escapes that, but then has to be placed against its badge by hand.
export default function anchorToBadge(badge, panel) {
  const box = badge.getBoundingClientRect()
  const size = panel.getBoundingClientRect()
  const below = box.bottom + 6

  panel.style.left = `${Math.min(box.left, window.innerWidth - size.width - 12)}px`
  panel.style.top = `${below + size.height > window.innerHeight ? box.top - size.height - 6 : below}px`
}
