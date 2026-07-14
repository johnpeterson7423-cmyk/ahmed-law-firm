import { Controller } from "@hotwired/stimulus"

// Soft 3D tilt tracking for the hero preview
export default class extends Controller {
  static targets = ["card"]

  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    if (!this.hasCardTarget) return

    this.onMove = (event) => {
      const rect = this.cardTarget.getBoundingClientRect()
      const x = (event.clientX - rect.left) / rect.width
      const y = (event.clientY - rect.top) / rect.height
      const rotateY = (x - 0.5) * 14
      const rotateX = (0.5 - y) * 10

      this.cardTarget.style.setProperty("--tilt-x", `${rotateX}deg`)
      this.cardTarget.style.setProperty("--tilt-y", `${rotateY}deg`)
      this.cardTarget.style.setProperty("--glare-x", `${x * 100}%`)
      this.cardTarget.style.setProperty("--glare-y", `${y * 100}%`)
      this.cardTarget.classList.add("is-tilting")
    }

    this.onLeave = () => {
      this.cardTarget.style.setProperty("--tilt-x", "2deg")
      this.cardTarget.style.setProperty("--tilt-y", "-6deg")
      this.cardTarget.classList.remove("is-tilting")
    }

    this.element.addEventListener("pointermove", this.onMove)
    this.element.addEventListener("pointerleave", this.onLeave)
  }

  disconnect() {
    this.element.removeEventListener("pointermove", this.onMove)
    this.element.removeEventListener("pointerleave", this.onLeave)
  }
}
