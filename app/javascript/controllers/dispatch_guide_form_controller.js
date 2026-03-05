import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["privateTransport", "publicTransport", "recipientSection"]

  toggleTransport() {
    const modality = this.element.querySelector('[name*="transport_modality"]').value
    if (modality === "private") {
      this.privateTransportTarget.classList.remove("hidden")
      this.publicTransportTarget.classList.add("hidden")
    } else {
      this.privateTransportTarget.classList.add("hidden")
      this.publicTransportTarget.classList.remove("hidden")
    }
  }

  toggleGuideType() {
    // Guide type toggle requires page reload to swap recipient/shipper fields
    // This is handled server-side through the form partial
  }
}
