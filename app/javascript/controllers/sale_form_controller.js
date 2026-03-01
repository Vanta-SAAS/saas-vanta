import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "itemsContainer",
    "itemsList",
    "itemRow",
    "itemTemplate",
    "productSearch",
    "productDropdown",
    "productSearchContainer",
    "addItemSection",
    "subtotal",
    "tax",
    "total",
    "destinationContainer",
    "codeField",
    "sellerContainer"
  ]

  static values = {
    productsUrl: { type: String, default: "/products/search" },
    igvRate: { type: Number, default: 0.18 }
  }

  connect() {
    this.itemIndex = this.itemRowTargets.length
    this.searchTimeout = null

    this.calculateTotals()

    // click outside
    this.boundOutsideClick = this.handleOutsideClick.bind(this)
    document.addEventListener("click", this.boundOutsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this.boundOutsideClick)
  }

  searchProducts(event) {
    const query = event.target.value.trim()

    clearTimeout(this.searchTimeout)
    this.searchTimeout = setTimeout(() => {
      this.fetchProducts(query)
    }, 300)
  }

  async fetchProducts(query) {
    const separator = this.productsUrlValue.includes("?") ? "&" : "?"
    const url = `${this.productsUrlValue}${separator}q=${encodeURIComponent(query)}`

    try {
      const response = await fetch(url, {
        headers: {
          "Accept": "text/html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (response.ok) {
        const html = await response.text()
        this.renderProductDropdown(html)
      }
    } catch (error) {
      console.error("Error fetching products:", error)
    }
  }

  renderProductDropdown(html) {
    if (!this.hasProductDropdownTarget) return

    this.productDropdownTarget.innerHTML = html
    this.productDropdownTarget.classList.remove("hidden")
  }

  showProductDropdown() {
    if (this.productSearchTarget.value.trim() === "") {
      this.fetchProducts("")
    }
  }

  handleOutsideClick(event) {
    if (this.hasProductSearchContainerTarget &&
      !this.productSearchContainerTarget.contains(event.target)) {
      this.hideProductDropdown()
    }
  }

  hideProductDropdown() {
    if (this.hasProductDropdownTarget) {
      this.productDropdownTarget.classList.add("hidden")
    }
  }

  selectProduct(event) {
    const button = event.currentTarget
    const productId = button.dataset.productId
    const productName = button.dataset.productName
    const basePrice = parseFloat(button.dataset.productPrice) || 0

    // Check if product already exists in items
    const existingProduct = Array.from(this.itemRows).find(row => {
      const input = row.querySelector(".product-id-input")
      return input && input.value === productId
    })

    if (existingProduct) {
      alert("Este producto ya esta en la venta")
      this.hideProductDropdown()
      this.productSearchTarget.value = ""
      return
    }

    this.addItem(productId, productName, basePrice)

    this.productSearchTarget.value = ""
    this.hideProductDropdown()
  }

  addItem(productId, productName, productPrice) {
    const template = this.itemTemplateTarget.content.cloneNode(true)
    const row = template.querySelector("tr")

    row.querySelectorAll("[name]").forEach(input => {
      input.name = input.name.replace("NEW_INDEX", this.itemIndex)
    })

    const productNameSpan = row.querySelector(".product-name")
    const productIdInput = row.querySelector(".product-id-input")
    const unitPriceInput = row.querySelector(".unit-price-input")

    productNameSpan.textContent = productName
    productIdInput.value = productId
    unitPriceInput.value = productPrice.toFixed(2)

    this.itemsListTarget.appendChild(row)

    this.itemIndex++
    this.calculateRowTotal({ target: unitPriceInput })
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
    const quantity = parseFloat(row.querySelector(".quantity-input").value) || 0
    const unitPrice = parseFloat(row.querySelector(".unit-price-input").value) || 0
    const total = quantity * unitPrice

    const totalSpan = row.querySelector(".row-total")
    totalSpan.textContent = `S/ ${total.toFixed(2)}`

    this.calculateTotals()
  }

  get itemRows() {
    return this.itemsListTarget.querySelectorAll("tr")
  }

  calculateTotals() {
    let total = 0

    this.itemRows.forEach(row => {
      if (row.classList.contains("hidden")) return

      const quantity = parseFloat(row.querySelector(".quantity-input")?.value) || 0
      const unitPrice = parseFloat(row.querySelector(".unit-price-input")?.value) || 0
      total += quantity * unitPrice
    })

    const subtotal = total / (1 + this.igvRateValue)
    const tax = total - subtotal

    if (this.hasSubtotalTarget) {
      this.subtotalTarget.textContent = subtotal.toFixed(2)
    }
    if (this.hasTaxTarget) {
      this.taxTarget.textContent = tax.toFixed(2)
    }
    if (this.hasTotalTarget) {
      this.totalTarget.textContent = total.toFixed(2)
    }
  }
}
