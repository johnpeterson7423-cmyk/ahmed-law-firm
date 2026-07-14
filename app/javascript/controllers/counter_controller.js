import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { duration: { type: Number, default: 1000 } }

  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    const raw = this.element.textContent.trim()
    const match = raw.match(/^(\d+)(.*)$/)
    if (!match) return

    const target = Number(match[1])
    const suffix = match[2] || ""
    const start = performance.now()

    const tick = (now) => {
      const progress = Math.min((now - start) / this.durationValue, 1)
      const eased = 1 - Math.pow(1 - progress, 3)
      this.element.textContent = `${Math.round(target * eased)}${suffix}`
      if (progress < 1) requestAnimationFrame(tick)
    }

    this.element.textContent = `0${suffix}`
    requestAnimationFrame(tick)
  }
}
