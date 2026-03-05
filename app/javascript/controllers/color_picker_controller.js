import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["primaryInput", "primaryPreview", "primaryHex",
                     "secondaryInput", "secondaryPreview", "secondaryHex",
                     "primaryReset", "secondaryReset"]

  static values = {
    defaultPrimary: { type: String, default: "#059669" },
    defaultSecondary: { type: String, default: "#374151" }
  }

  connect() {
    this.updatePrimaryPreview()
    this.updateSecondaryPreview()
  }

  updatePrimaryPreview() {
    const color = this.primaryInputTarget.value
    this.primaryPreviewTarget.style.backgroundColor = color
    this.primaryHexTarget.textContent = color
    this.applyPrimaryOverrides(color)

    if (this.hasPrimaryResetTarget) {
      this.primaryResetTarget.classList.toggle("hidden", color === this.defaultPrimaryValue)
    }
  }

  updateSecondaryPreview() {
    const color = this.secondaryInputTarget.value
    this.secondaryPreviewTarget.style.backgroundColor = color
    this.secondaryHexTarget.textContent = color
    this.applySecondaryOverrides(color)

    if (this.hasSecondaryResetTarget) {
      this.secondaryResetTarget.classList.toggle("hidden", color === this.defaultSecondaryValue)
    }
  }

  resetPrimary() {
    this.primaryInputTarget.value = this.defaultPrimaryValue
    this.updatePrimaryPreview()
  }

  resetSecondary() {
    this.secondaryInputTarget.value = this.defaultSecondaryValue
    this.updateSecondaryPreview()
  }

  applyPrimaryOverrides(hex) {
    const root = document.documentElement
    root.style.setProperty("--primary", hex)
    root.style.setProperty("--primary-light", this.lighten(hex, 0.85))
    root.style.setProperty("--primary-muted", this.lighten(hex, 0.92))
    root.style.setProperty("--ring", hex)
    root.style.setProperty("--success", hex)
    root.style.setProperty("--success-light", this.lighten(hex, 0.85))
    root.style.setProperty("--sidebar-icon-active", hex)
    root.style.setProperty("--sidebar-active-bg", this.lighten(hex, 0.92))
  }

  applySecondaryOverrides(hex) {
    document.documentElement.style.setProperty("--secondary", hex)
  }

  hexToRgb(hex) {
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex)
    return result ? {
      r: parseInt(result[1], 16),
      g: parseInt(result[2], 16),
      b: parseInt(result[3], 16)
    } : { r: 0, g: 0, b: 0 }
  }

  lighten(hex, amount) {
    const { r, g, b } = this.hexToRgb(hex)
    const lr = Math.round(r + (255 - r) * amount)
    const lg = Math.round(g + (255 - g) * amount)
    const lb = Math.round(b + (255 - b) * amount)
    return `#${lr.toString(16).padStart(2, "0")}${lg.toString(16).padStart(2, "0")}${lb.toString(16).padStart(2, "0")}`
  }
}
