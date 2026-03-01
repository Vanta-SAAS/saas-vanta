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
    "customerContainer",
    "destinationContainer",
    "codeField",
    "notesHint",
    "sellerContainer"
  ]

  static values = {
    productsUrl: { type: String, default: "/products/search" },
    prefillUrl: { type: String, default: "/customer_quotes/prefill" },
    igvRate: { type: Number, default: 0.18 }
  }

  connect() {
    this.itemIndex = this.itemRowTargets.length
    this.selectedCustomerId = this.getSelectedCustomerId()
    this.searchTimeout = null
    this.priceHistory = {} // { product_id: last_price }

    this.calculateTotals()

    // click outside
    this.boundOutsideClick = this.handleOutsideClick.bind(this)
    document.addEventListener("click", this.boundOutsideClick)

    // customer polling
    this.customerInterval = setInterval(() => {
      const newCustomerId = this.getSelectedCustomerId()
      if (newCustomerId !== this.selectedCustomerId) {
        this.selectedCustomerId = newCustomerId
        this.handleCustomerChange()
      }
    }, 500)
  }

  disconnect() {
    document.removeEventListener("click", this.boundOutsideClick)
    clearInterval(this.customerInterval)
  }

  getSelectedCustomerId() {
    const input = document.querySelector('input[name="customer_quote[customer_id]"]')
    return input ? input.value : null
  }

  async handleCustomerChange() {
    this.selectedCustomerId = this.getSelectedCustomerId()

    if (!this.selectedCustomerId) return

    // Fetch customer data to get ubigeo
    try {
      const response = await fetch(`/customers/${this.selectedCustomerId}.json`, {
        headers: {
          "Accept": "application/json",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (response.ok) {
        const customer = await response.json()
        if (customer.ubigeo_id) {
          this.updateDestinationFromCustomer(customer.ubigeo_id, customer.ubigeo_display)
        }
      }
    } catch (error) {
      console.error("Error fetching customer data:", error)
    }

    // Fetch prefill data (notes + price history)
    this.fetchPrefillData()
  }

  async fetchPrefillData() {
    const params = new URLSearchParams({ customer_id: this.selectedCustomerId })

    try {
      const response = await fetch(`${this.prefillUrlValue}?${params}`, {
        headers: {
          "Accept": "application/json",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (response.ok) {
        const data = await response.json()
        this.applyPrefillData(data)
      }
    } catch (error) {
      console.error("Error fetching prefill data:", error)
    }
  }

  applyPrefillData(data) {
    // Apply last notes
    const notesField = this.element.querySelector('textarea[name="customer_quote[notes]"]')
    if (data.last_notes && notesField && !notesField.value.trim()) {
      notesField.value = data.last_notes
      if (this.hasNotesHintTarget) {
        this.notesHintTarget.classList.remove("hidden")
      }
    }

    // Store price history for use when adding products
    this.priceHistory = data.price_history || {}
  }

  updateDestinationFromCustomer(ubigeoId, ubigeoDisplay) {
    const destinationInput = document.querySelector('input[name="customer_quote[destination_id]"]')
    if (destinationInput) {
      destinationInput.value = ubigeoId
    }

    const destinationCombobox = document.querySelector('#destination_combobox')
    if (destinationCombobox) {
      const textInput = destinationCombobox.querySelector('input[type="text"]') ||
        destinationCombobox.closest('.hw-combobox')?.querySelector('input[type="text"]')
      if (textInput) {
        textInput.value = ubigeoDisplay || ''
      }
    }

    const hwCombobox = document.querySelector('[data-controller*="hw-combobox"]#destination_combobox')
    if (hwCombobox) {
      const actorInput = hwCombobox.querySelector('input[role="combobox"]')
      if (actorInput) {
        actorInput.value = ubigeoDisplay || ''
      }
    }
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
      alert("Este producto ya esta en la cotizacion")
      this.hideProductDropdown()
      this.productSearchTarget.value = ""
      return
    }

    // Use historical price if available, otherwise use base sell price
    const historicalPrice = this.priceHistory[productId]
    const price = historicalPrice !== undefined ? historicalPrice : basePrice

    this.addItem(productId, productName, price, historicalPrice !== undefined)

    this.productSearchTarget.value = ""
    this.hideProductDropdown()
  }

  addItem(productId, productName, productPrice, isHistorical = false) {
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

    // Show warning icon next to price input when using historical price
    if (isHistorical) {
      const indicator = row.querySelector(".price-history-indicator")
      if (indicator) {
        indicator.classList.remove("hidden")
      }
    }

    this.itemsListTarget.appendChild(row)

    this.itemIndex++
    this.calculateRowTotal({ target: unitPriceInput })
    this.calculateTotals()
  }

  togglePriceHint(event) {
    const tooltip = event.currentTarget.closest(".price-history-indicator").querySelector(".price-history-tooltip")
    if (tooltip) {
      tooltip.classList.toggle("hidden")
    }
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
