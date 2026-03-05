import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["productType", "sourceType", "providerContainer", "goodsOnly", "purchasedOnly", "unitToggle", "unitFields", "unitSelect"]

  connect() {
    this.toggleProductType()
    this.toggleProvider()
    this.toggleUnitFields()
  }

  toggleProductType() {
    if (!this.hasProductTypeTarget) return

    const isService = this.productTypeTarget.value === "service"

    this.goodsOnlyTargets.forEach(el => {
      el.classList.toggle("hidden", isService)
      el.querySelectorAll("input, select").forEach(input => {
        input.disabled = isService
      })
    })

    this.toggleProvider()
  }

  toggleProvider() {
    if (!this.hasSourceTypeTarget) return

    const isService = this.hasProductTypeTarget && this.productTypeTarget.value === "service"
    const isPurchased = this.sourceTypeTarget.value === "purchased"

    if (this.hasProviderContainerTarget) {
      const hideProvider = isService || !isPurchased
      this.providerContainerTarget.classList.toggle("hidden", hideProvider)
    }

    this.purchasedOnlyTargets.forEach(el => {
      const hide = isService || !isPurchased
      el.classList.toggle("hidden", hide)
      el.querySelectorAll("input, select").forEach(input => {
        input.disabled = hide
      })
    })
  }

  toggleUnitFields() {
    if (!this.hasUnitToggleTarget || !this.hasUnitFieldsTarget) return

    const show = this.unitToggleTarget.checked

    this.unitFieldsTarget.classList.toggle("hidden", !show)
    this.unitFieldsTarget.querySelectorAll("input, select").forEach(input => {
      input.disabled = !show
    })

    // Reset unit to "un" when unchecked
    if (!show && this.hasUnitSelectTarget) {
      this.unitSelectTarget.value = "un"
    }
  }
}
