// Turbo 8.0.21 dropped its same-page anchor handling (hotwired/turbo#1285), so
// an in-page jump now runs a full visit: the page re-renders and every unsaved
// edit in the form goes with it. Cancelling turbo:click hands the link back to
// the browser, which is the behaviour that change set out to arrive at.
export default function keepSamePageAnchorsNative() {
  addEventListener("turbo:click", (event) => {
    const target = new URL(event.detail.url)

    if (target.hash && samePage(target, window.location)) event.preventDefault()
  })
}

function samePage(target, current) {
  return target.origin === current.origin &&
    target.pathname === current.pathname &&
    target.search === current.search
}
