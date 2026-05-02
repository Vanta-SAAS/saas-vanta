import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["itemRow", "itemsList", "itemTemplate", "subtotalDisplay", "taxDisplay", "totalDisplay", "reasonInput"]

  connect() {
    this.itemIndex = this.itemRowTargets.length
    this.calculateTotals()
  }

  addItem(event) {
    event.preventDefault()
    this.appendItemRow()
  }

  appendItemRow({ description = "", quantity = 1, unitPrice = 0, itemType = "product", taxType = "gravado" } = {}) {
    const template = this.itemTemplateTarget.content.cloneNode(true)
    const row = template.querySelector("tr")

    row.querySelectorAll("[name]").forEach(input => {
      input.name = input.name.replace("NEW_INDEX", this.itemIndex)
    })

    const setVal = (selector, value) => {
      const el = row.querySelector(selector)
      if (el) el.value = value
    }
    setVal('input[type="text"]', description)
    setVal('input[name$="[item_type]"]', itemType)
    setVal('input[name$="[tax_type]"]', taxType)
    setVal(".quantity-input", quantity)
    setVal(".unit-price-input", unitPrice)

    this.itemsListTarget.appendChild(row)
    this.itemIndex++
    this.calculateTotals()
    return row
  }

  onReasonChange(event) {
    const value = event.detail?.value
    if (value === "disminucion_en_el_valor") {
      this.resetItemsForAdjustment()
    }
  }

  resetItemsForAdjustment() {
    this.itemRowTargets.forEach(row => {
      const destroyInput = row.querySelector(".destroy-input")
      if (destroyInput) {
        destroyInput.value = "1"
        row.classList.add("hidden")
      } else {
        row.remove()
      }
    })
    this.appendItemRow({
      description: "Ajuste por exceso facturado",
      quantity: 1,
      unitPrice: 0,
      itemType: "service",
      taxType: "gravado"
    })
  }

  removeItem(event) {
    const row = event.target.closest("tr")
    const destroyInput = row.querySelector(".destroy-input")

    if (destroyInput) {
      destroyInput.value = "1"
      row.classList.add("hidden")
    } else {
      row.remove()
    }

    this.calculateTotals()
  }

  calculateRowTotal(event) {
    const row = event.target.closest("tr")
    const quantity = parseFloat(row.querySelector(".quantity-input")?.value) || 0
    const unitPrice = parseFloat(row.querySelector(".unit-price-input")?.value) || 0
    const total = quantity * unitPrice
    const totalSpan = row.querySelector(".row-total")
    if (totalSpan) {
      totalSpan.textContent = `S/ ${total.toFixed(2)}`
    }
    this.calculateTotals()
  }

  calculateTotals() {
    let total = 0

    this.itemRowTargets.forEach(row => {
      if (row.classList.contains("hidden")) return
      const quantity = parseFloat(row.querySelector(".quantity-input")?.value) || 0
      const unitPrice = parseFloat(row.querySelector(".unit-price-input")?.value) || 0
      total += quantity * unitPrice
    })

    const igvRate = 0.18
    const subtotal = total / (1 + igvRate)
    const tax = total - subtotal

    if (this.hasSubtotalDisplayTarget) this.subtotalDisplayTarget.textContent = `S/ ${subtotal.toFixed(2)}`
    if (this.hasTaxDisplayTarget) this.taxDisplayTarget.textContent = `S/ ${tax.toFixed(2)}`
    if (this.hasTotalDisplayTarget) this.totalDisplayTarget.textContent = `S/ ${total.toFixed(2)}`
  }
}
