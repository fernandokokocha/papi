import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "link", "card"]
  static storageKey = "papi.sidebar.collapsed"
  static anchorKey = "papi.anchor.enabled"

  // Keys that scroll the page — pressing them releases a pinned selection.
  static scrollKeys = ["ArrowUp", "ArrowDown", "PageUp", "PageDown", "Home", "End", " "]

  connect() {
    this.apply(localStorage.getItem(this.constructor.storageKey) === "1")
    this.pinnedId = null

    // Scroll-spy is opt-out; default on unless the user disabled it before.
    // The control lives in the Display popover; it flips localStorage and fires
    // "anchor:changed", which we re-read here.
    this.anchorEnabled = localStorage.getItem(this.constructor.anchorKey) !== "0"
    this.onAnchorChanged = this.applyAnchorSetting.bind(this)
    window.addEventListener("anchor:changed", this.onAnchorChanged)

    this.onScroll = this.scheduleUpdate.bind(this)
    this.onUserScroll = this.unpin.bind(this)
    this.onKey = this.handleKey.bind(this)
    this.onClick = this.handleLinkClick.bind(this)

    window.addEventListener("scroll", this.onScroll, { passive: true })
    window.addEventListener("resize", this.onScroll, { passive: true })
    window.addEventListener("wheel", this.onUserScroll, { passive: true })
    window.addEventListener("touchmove", this.onUserScroll, { passive: true })
    window.addEventListener("keydown", this.onKey)
    this.element.addEventListener("click", this.onClick)

    this.updateCurrent()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
    window.removeEventListener("resize", this.onScroll)
    window.removeEventListener("wheel", this.onUserScroll)
    window.removeEventListener("touchmove", this.onUserScroll)
    window.removeEventListener("keydown", this.onKey)
    window.removeEventListener("anchor:changed", this.onAnchorChanged)
    this.element.removeEventListener("click", this.onClick)
  }

  scheduleUpdate() {
    if (this.ticking) return
    this.ticking = true
    requestAnimationFrame(() => {
      this.ticking = false
      this.updateCurrent()
    })
  }

  updateCurrent() {
    if (!this.anchorEnabled || this.cardTargets.length === 0) return

    const current = this.pinnedId
      ? this.cardTargets.find((card) => card.id === this.pinnedId) || this.cardTargets[0]
      : this.currentByScroll()

    this.cardTargets.forEach((card) => {
      card.classList.toggle("anchor-active", card === current)
    })
    this.linkTargets.forEach((link) => {
      link.classList.toggle("sidebar-link-active", link.getAttribute("href") === `#${current.id}`)
    })
  }

  // The trigger line is wherever an anchor click parks a card: below the sticky
  // rail, which the cards declare as their scroll-margin-top.
  triggerY() {
    return parseFloat(getComputedStyle(this.cardTargets[0]).scrollMarginTop) + 1
  }

  // Scroll-spy pick: the last card whose top has crossed the trigger line. Once
  // the page is scrolled all the way down, the bottom cards can't reach it, so
  // fall back to the final card.
  currentByScroll() {
    const triggerY = this.triggerY()
    let current = this.cardTargets[0]
    this.cardTargets.forEach((card) => {
      if (card.getBoundingClientRect().top <= triggerY) current = card
    })

    const atBottom = window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 2
    if (atBottom) current = this.cardTargets[this.cardTargets.length - 1]

    return current
  }

  // Clicking a sidebar link pins its card as the selection and flashes it. The
  // native anchor scrolls there; the pin holds until the user scrolls again.
  handleLinkClick(event) {
    if (!this.anchorEnabled) return
    const link = event.target.closest('[data-sidebar-target~="link"]')
    if (!link) return
    const card = document.getElementById(link.getAttribute("href").slice(1))
    if (!card) return

    this.pinnedId = card.id
    card.classList.remove("anchor-flash")
    void card.offsetWidth // restart the animation
    card.classList.add("anchor-flash")
    card.addEventListener("animationend", () => card.classList.remove("anchor-flash"), { once: true })

    this.updateCurrent()
  }

  handleKey(event) {
    if (this.constructor.scrollKeys.includes(event.key)) this.unpin()
  }

  // Release a pinned selection and resume scroll-spy.
  unpin() {
    if (!this.pinnedId) return
    this.pinnedId = null
    this.scheduleUpdate()
  }

  // Re-read the anchor setting after the Display popover changed it.
  applyAnchorSetting() {
    this.anchorEnabled = localStorage.getItem(this.constructor.anchorKey) !== "0"
    if (this.anchorEnabled) {
      this.updateCurrent()
    } else {
      this.pinnedId = null
      this.clearAnchor()
    }
  }

  clearAnchor() {
    this.cardTargets.forEach((card) => card.classList.remove("anchor-active"))
    this.linkTargets.forEach((link) => link.classList.remove("sidebar-link-active"))
  }

  toggle() {
    this.apply(this.element.dataset.sidebar !== "collapsed")
  }

  apply(collapsed) {
    this.element.dataset.sidebar = collapsed ? "collapsed" : "open"
    localStorage.setItem(this.constructor.storageKey, collapsed ? "1" : "0")
    this.buttonTarget.title = collapsed ? "Show contents" : "Hide contents"
  }
}
