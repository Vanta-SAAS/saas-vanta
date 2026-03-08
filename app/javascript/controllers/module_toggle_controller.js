import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "children"]

  connect() {
    this.updateVisibility()
  }

  toggle() {
    this.updateVisibility()
  }

  updateVisibility() {
    const enabled = this.toggleTarget.checked

    if (this.hasChildrenTarget) {
      this.childrenTarget.classList.toggle("hidden", !enabled)

      this.childrenTarget.querySelectorAll("input[type=checkbox]").forEach(cb => {
        cb.disabled = !enabled
      })
    }
  }
}
