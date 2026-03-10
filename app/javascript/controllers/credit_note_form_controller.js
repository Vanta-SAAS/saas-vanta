import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["itemRow", "itemsList", "itemTemplate", "subtotalDisplay", "taxDisplay", "totalDisplay"]

  connect() {
    this.itemIndex = this.itemRowTargets.length
    this.calculateTotals()
  }

  addItem(event) {
    event.preventDefault()
    const template = this.itemTemplateTarget.content.cloneNode(true)
    const row = template.querySelector("tr")

    row.querySelectorAll("[name]").forEach(input => {
      input.name = input.name.replace("NEW_INDEX", this.itemIndex)
    })

    this.itemsListTarget.appendChild(row)
    this.itemIndex++
    this.calculateTotals()
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
