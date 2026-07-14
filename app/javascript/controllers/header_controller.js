import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.onScroll = () => {
      this.element.classList.toggle("is-scrolled", window.scrollY > 10)
    }
    this.onScroll()
    window.addEventListener("scroll", this.onScroll, { passive: true })
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
  }
}
