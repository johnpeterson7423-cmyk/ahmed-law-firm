import { Controller } from "@hotwired/stimulus"

// Toggles the light/dark theme by flipping data-theme on <html> and
// persisting the choice. The initial theme is set synchronously by an
// inline script in the layout <head> to avoid a flash of the wrong theme.
export default class extends Controller {
  toggle() {
    const root = document.documentElement
    const next = root.getAttribute("data-theme") === "light" ? "dark" : "light"

    root.setAttribute("data-theme", next)

    try {
      localStorage.setItem("theme", next)
    } catch (e) {
      // ignore (private browsing / storage disabled)
    }
  }
}
