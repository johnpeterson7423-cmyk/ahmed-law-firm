import { Controller } from "@hotwired/stimulus"

// Soft loading state during Turbo Drive / form navigations
export default class extends Controller {
  connect() {
    this.onStart = () => this.element.classList.add("turbo-loading")
    this.onEnd = () => this.element.classList.remove("turbo-loading")

    document.addEventListener("turbo:visit", this.onStart)
    document.addEventListener("turbo:submit-start", this.onStart)
    document.addEventListener("turbo:load", this.onEnd)
    document.addEventListener("turbo:submit-end", this.onEnd)
    document.addEventListener("turbo:frame-load", this.onEnd)
  }

  disconnect() {
    document.removeEventListener("turbo:visit", this.onStart)
    document.removeEventListener("turbo:submit-start", this.onStart)
    document.removeEventListener("turbo:load", this.onEnd)
    document.removeEventListener("turbo:submit-end", this.onEnd)
    document.removeEventListener("turbo:frame-load", this.onEnd)
  }
}
