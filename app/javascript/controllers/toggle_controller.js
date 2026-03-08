import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "content"]

  toggle() {
    const checked = this.triggerTarget.checked
    this.contentTarget.classList.toggle("hidden", !checked)
  }
}
