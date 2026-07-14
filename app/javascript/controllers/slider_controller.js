import { Controller } from "@hotwired/stimulus"

// A native-scroll carousel. Arrows/dots drive scrollTo/scrollBy on the
// viewport, and a scroll listener keeps the dots in sync. The slide set is
// duplicated once in the DOM (the "loop" copy, hidden from a11y) so autoplay
// can keep scrolling in a single direction and silently wrap back by one set
// width when it crosses into the duplicate — giving the illusion of an
// endless loop instead of snapping back to the start.
export default class extends Controller {
  static targets = ["viewport", "slide", "loopSlide", "dot", "prev", "next"]
  static values = { interval: { type: Number, default: 4000 } }

  connect() {
    this.onScroll = this.onScroll.bind(this)
    this.viewportTarget.addEventListener("scroll", this.onScroll, { passive: true })

    this.pause = this.pause.bind(this)
    this.resume = this.resume.bind(this)
    this.element.addEventListener("mouseenter", this.pause)
    this.element.addEventListener("mouseleave", this.resume)
    this.element.addEventListener("focusin", this.pause)
    this.element.addEventListener("focusout", this.resume)

    this.sync()
    this.resume()
  }

  disconnect() {
    this.viewportTarget.removeEventListener("scroll", this.onScroll)
    this.element.removeEventListener("mouseenter", this.pause)
    this.element.removeEventListener("mouseleave", this.resume)
    this.element.removeEventListener("focusin", this.pause)
    this.element.removeEventListener("focusout", this.resume)
    clearTimeout(this.scrollTimer)
    clearInterval(this.autoplayTimer)
  }

  onScroll() {
    clearTimeout(this.scrollTimer)
    this.scrollTimer = setTimeout(() => this.sync(), 80)
  }

  prev() {
    this.viewportTarget.scrollBy({ left: -this.step(), behavior: "smooth" })
    this.resume()
  }

  next() {
    this.viewportTarget.scrollBy({ left: this.step(), behavior: "smooth" })
    this.resume()
  }

  goTo(event) {
    const slide = this.slideTargets[Number(event.currentTarget.dataset.index)]
    if (slide) this.viewportTarget.scrollTo({ left: slide.offsetLeft, behavior: "smooth" })
    this.resume()
  }

  // Manual prev/next jump by almost a full viewport.
  step() {
    return this.viewportTarget.clientWidth * 0.85
  }

  // Autoplay advances by exactly one card's width (including gap) so it
  // always lands precisely on a scroll-snap point — an arbitrary pixel
  // amount would drift out of sync with the snap points and stall.
  cardStep() {
    return this.slideTargets.length > 1
      ? this.slideTargets[1].offsetLeft - this.slideTargets[0].offsetLeft
      : this.step()
  }

  // Width of one full lap (the original set) — the loop copy starts here.
  setWidth() {
    return this.hasLoopSlideTarget ? this.loopSlideTargets[0].offsetLeft : this.viewportTarget.scrollWidth
  }

  pause() {
    clearInterval(this.autoplayTimer)
  }

  resume() {
    clearInterval(this.autoplayTimer)
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    this.autoplayTimer = setInterval(() => this.advance(), this.intervalValue)
  }

  // Always moves forward. Once scrolled past the first set, silently (no
  // animation) rewinds by exactly one set width — since the loop copy is
  // visually identical, the rewind is imperceptible.
  advance() {
    const viewport = this.viewportTarget
    const setWidth = this.setWidth()

    if (viewport.scrollLeft >= setWidth - 4) {
      viewport.scrollLeft -= setWidth
    }

    viewport.scrollBy({ left: this.cardStep(), behavior: "smooth" })
  }

  sync() {
    const viewport = this.viewportTarget
    const setWidth = this.setWidth()
    const position = viewport.scrollLeft % setWidth

    const activeIndex = this.slideTargets.reduce((closest, slide, i) => {
      const delta = Math.abs(slide.offsetLeft - position)
      return delta < closest.delta ? { i, delta } : closest
    }, { i: 0, delta: Infinity }).i

    this.dotTargets.forEach((dot, i) => {
      const active = i === activeIndex
      dot.classList.toggle("practice__dot--active", active)
      dot.setAttribute("aria-current", active ? "true" : "false")
    })
  }
}
