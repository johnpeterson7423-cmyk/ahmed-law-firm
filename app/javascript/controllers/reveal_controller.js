import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    delay: { type: Number, default: 70 },
    immediate: { type: Boolean, default: true }
  }

  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.items().forEach((el) => el.classList.add("reveal-ready"))
      return
    }

    if (this.immediateValue) {
      requestAnimationFrame(() => this.reveal())
      return
    }

    this.observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) {
        this.reveal()
        this.observer.disconnect()
      }
    }, { threshold: 0.1 })

    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  items() {
    return Array.from(this.element.querySelectorAll("[data-reveal]")).filter((el) => {
      const owner = el.closest("[data-controller~='reveal']")
      if (el === owner) {
        const parentOwner = el.parentElement?.closest("[data-controller~='reveal']")
        return parentOwner === this.element
      }
      return owner === this.element
    })
  }

  reveal() {
    if (this.revealed) return
    this.revealed = true

    this.items().forEach((el, index) => {
      el.style.setProperty("--reveal-delay", `${index * this.delayValue}ms`)
      el.classList.add("reveal-ready")
    })
  }
}
