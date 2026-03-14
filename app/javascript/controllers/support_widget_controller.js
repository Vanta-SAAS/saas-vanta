import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  toggle() {
    this.panelTarget.classList.toggle("hidden")
  }

  close() {
    this.panelTarget.classList.add("hidden")
  }

  // Close when clicking outside
  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  connect() {
    this.clickOutsideHandler = this.clickOutside.bind(this)
    document.addEventListener("click", this.clickOutsideHandler)
  }

  disconnect() {
    document.removeEventListener("click", this.clickOutsideHandler)
  }
}
