import { Controller } from "@hotwired/stimulus"

// Animates a formatted number (eg. "$1,500,000") counting up from 0
// to its final value once the element scrolls into view.
export default class extends Controller {
  static values = { duration: { type: Number, default: 1400 } }

  connect() {
    const match = this.element.textContent.trim().match(/^(\D*)([\d,]+)(\D*)$/)
    if (!match) return

    this.prefix = match[1]
    this.suffix = match[3]
    this.target = Number(match[2].replace(/,/g, ""))

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    this.played = false
    this.render(0)

    this.observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting && !this.played) {
        this.played = true
        requestAnimationFrame((now) => this.animate(now))
        this.observer.disconnect()
      }
    }, { threshold: 0.4 })

    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  animate(startTime) {
    this.startTime ??= startTime
    const progress = Math.min((startTime - this.startTime) / this.durationValue, 1)
    const eased = 1 - Math.pow(1 - progress, 3)

    this.render(Math.round(this.target * eased))

    if (progress < 1) {
      requestAnimationFrame((now) => this.animate(now))
    }
  }

  render(value) {
    this.element.textContent = `${this.prefix}${value.toLocaleString("en-US")}${this.suffix}`
  }
}
