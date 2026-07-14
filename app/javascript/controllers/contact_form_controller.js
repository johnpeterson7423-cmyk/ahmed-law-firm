import { Controller } from "@hotwired/stimulus"

// This form isn't wired to a backend yet (no inquiry model/mailer exists),
// so submitting just swaps in an acknowledgment instead of doing a bare
// page reload with no feedback.
export default class extends Controller {
  static targets = ["form", "success"]

  submit(event) {
    event.preventDefault()
    this.formTarget.hidden = true
    this.successTarget.hidden = false
  }
}
