import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "dropdown", "input", "label", "arrow"]

  connect() {
    this.close = this.close.bind(this)
    document.addEventListener("click", this.close)
  }

  disconnect() {
    document.removeEventListener("click", this.close)
  }

  toggle(event) {
    event.stopPropagation()
    this.dropdownTarget.classList.toggle("hidden")
    this.arrowTarget.classList.toggle("rotate-180")
  }

  select(event) {
    const { value, label } = event.currentTarget.dataset
    this.inputTarget.value = value
    this.labelTarget.textContent = label
    this.labelTarget.classList.remove("text-muted-foreground")
    this.labelTarget.classList.add("text-foreground")
    this.dropdownTarget.classList.add("hidden")
    this.arrowTarget.classList.remove("rotate-180")
  }

  close(event) {
    if (!this.element.contains(event.target)) {
      this.dropdownTarget.classList.add("hidden")
      this.arrowTarget.classList.remove("rotate-180")
    }
  }
}
