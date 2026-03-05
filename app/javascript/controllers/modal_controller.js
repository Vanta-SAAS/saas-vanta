import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const frame = this.element.querySelector("turbo-frame")
    if (frame) {
      frame.addEventListener("turbo:frame-load", () => this.open())
    }
  }

  open() {
    this.element.showModal()
  }

  close() {
    this.element.close()
    const frame = this.element.querySelector("turbo-frame")
    if (frame) frame.innerHTML = ""
  }

  backdropClose(event) {
    if (event.target === this.element) this.close()
  }

  onSubmitEnd(event) {
    if (event.detail.success) this.close()
  }
}
