import { Controller } from "@hotwired/stimulus"

// Crossfades between testimonial slides, advancing on a timer (pausing on
// hover/focus) or via the dots.
export default class extends Controller {
  static targets = ["slide", "dot"]
  static values = { interval: { type: Number, default: 6000 } }

  connect() {
    this.index = 0

    this.pause = this.pause.bind(this)
    this.resume = this.resume.bind(this)
    this.element.addEventListener("mouseenter", this.pause)
    this.element.addEventListener("mouseleave", this.resume)
    this.element.addEventListener("focusin", this.pause)
    this.element.addEventListener("focusout", this.resume)

    this.resume()
  }

  disconnect() {
    clearInterval(this.timer)
    this.element.removeEventListener("mouseenter", this.pause)
    this.element.removeEventListener("mouseleave", this.resume)
    this.element.removeEventListener("focusin", this.pause)
    this.element.removeEventListener("focusout", this.resume)
  }

  show(event) {
    this.setActive(Number(event.currentTarget.dataset.index))
    this.resume()
  }

  pause() {
    clearInterval(this.timer)
  }

  resume() {
    clearInterval(this.timer)
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    this.timer = setInterval(() => this.next(), this.intervalValue)
  }

  next() {
    this.setActive((this.index + 1) % this.slideTargets.length)
  }

  setActive(index) {
    this.index = index

    this.slideTargets.forEach((slide, i) => {
      slide.classList.toggle("reviews__slide--active", i === index)
    })

    this.dotTargets.forEach((dot, i) => {
      const active = i === index
      dot.classList.toggle("reviews__dot--active", active)
      dot.setAttribute("aria-current", active ? "true" : "false")
    })
  }
}
