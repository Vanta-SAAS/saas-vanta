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
    "productHint",
    "addItemSection",
    "subtotal",
    "tax",
    "total",
    "customerContainer",
    "destinationContainer",
    "codeField",
    "notesHint"
  ]

  static values = {
    productsUrl: String,
    prefillUrl: { type: String, default: "/purchase_orders/prefill" },
    igvRate: { type: Number, default: 0.18 }
  }

  connect() {
    this.itemIndex = this.itemRowTargets.length
    this.selectedProviderId = this.getSelectedProviderId()
    this.selectedCustomerId = this.getSelectedCustomerId()
    this.searchTimeout = null

    this.updateProductHint()
    this.calculateTotals()

    // click outside
    this.boundOutsideClick = this.handleOutsideClick.bind(this)
    document.addEventListener("click", this.boundOutsideClick)

    // provider polling (fallback combobox)
    this.providerInterval = setInterval(() => {
      const newProviderId = this.getSelectedProviderId()
      if (newProviderId !== this.selectedProviderId) {
        this.selectedProviderId = newProviderId
        this.handleProviderChange()
      }
    }, 500)

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
    clearInterval(this.providerInterval)
    clearInterval(this.customerInterval)
  }

  getSelectedProviderId() {
    const input = document.querySelector('input[name="purchase_order[provider_id]"]')
    return input ? input.value : null
  }

  handleProviderChange() {
    this.selectedProviderId = this.getSelectedProviderId()
    this.updateProductHint()

    // Clear the product search
    if (this.hasProductSearchTarget) {
      this.productSearchTarget.value = ""
    }
    if (this.hasProductDropdownTarget) {
      this.productDropdownTarget.innerHTML = ""
      this.productDropdownTarget.classList.add("hidden")
    }
  }

  updateProductHint() {
    if (!this.hasProductHintTarget) return

    if (this.selectedProviderId) {
      this.productHintTarget.textContent = "Escribe para buscar productos"
      if (this.hasProductSearchTarget) {
        this.productSearchTarget.disabled = false
      }
    } else {
      this.productHintTarget.textContent = "Selecciona un proveedor primero"
      if (this.hasProductSearchTarget) {
        this.productSearchTarget.disabled = true
      }
    }
  }

  getSelectedCustomerId() {
    const input = document.querySelector('input[name="purchase_order[customer_id]"]')
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
    const notesField = this.element.querySelector('textarea[name="purchase_order[notes]"]')
    if (data.last_notes && notesField && !notesField.value.trim()) {
      notesField.value = data.last_notes
      if (this.hasNotesHintTarget) {
        this.notesHintTarget.classList.remove("hidden")
      }
    }
  }

  updateDestinationFromCustomer(ubigeoId, ubigeoDisplay) {
    // Update the hidden input value
    const destinationInput = document.querySelector('input[name="purchase_order[destination_id]"]')
    if (destinationInput) {
      destinationInput.value = ubigeoId
    }

    // Update the combobox display text
    const destinationCombobox = document.querySelector('#destination_combobox')
    if (destinationCombobox) {
      // For hotwire_combobox, we need to find the text input and update it
      const textInput = destinationCombobox.querySelector('input[type="text"]') ||
        destinationCombobox.closest('.hw-combobox')?.querySelector('input[type="text"]')
      if (textInput) {
        textInput.value = ubigeoDisplay || ''
      }
    }

    // Try alternative selector for hotwire combobox
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

    if (!this.selectedProviderId) {
      return
    }

    // Debounce the search
    clearTimeout(this.searchTimeout)
    this.searchTimeout = setTimeout(() => {
      this.fetchProducts(query)
    }, 300)
  }

  async fetchProducts(query) {
    if (!this.selectedProviderId) return

    const url = `/providers/${this.selectedProviderId}/products?q=${encodeURIComponent(query)}&form_controller=purchase-order-form`

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
    if (this.selectedProviderId && this.productSearchTarget.value.trim() === "") {
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
    const productPrice = parseFloat(button.dataset.productPrice) || 0

    // Check if product already exists in items
    const existingProduct = Array.from(this.itemRows).find(row => {
      const input = row.querySelector(".product-id-input")
      return input && input.value === productId
    })

    if (existingProduct) {
      alert("Este producto ya esta en la orden")
      this.hideProductDropdown()
      this.productSearchTarget.value = ""
      return
    }

    // Add new item
    this.addItem(productId, productName, productPrice)

    // Clear search and hide dropdown
    this.productSearchTarget.value = ""
    this.hideProductDropdown()
  }

  addItem(productId, productName, productPrice) {
    const template = this.itemTemplateTarget.content.cloneNode(true)
    const row = template.querySelector("tr")

    // Update indexes in the template
    row.querySelectorAll("[name]").forEach(input => {
      input.name = input.name.replace("NEW_INDEX", this.itemIndex)
    })

    // Set product data
    const productNameSpan = row.querySelector(".product-name")
    const productIdInput = row.querySelector(".product-id-input")
    const unitPriceInput = row.querySelector(".unit-price-input")

    productNameSpan.textContent = productName
    productIdInput.value = productId
    unitPriceInput.value = productPrice.toFixed(2)

    // Append to list
    this.itemsListTarget.appendChild(row)

    this.itemIndex++
    this.calculateRowTotal({ target: unitPriceInput })
    this.calculateTotals()
  }

  removeItem(event) {
    const row = event.target.closest("tr")
    const destroyInput = row.querySelector(".destroy-input")

    if (destroyInput) {
      // Mark for destruction (existing item)
      destroyInput.value = "1"
      row.classList.add("hidden")
    } else {
      // Remove from DOM (new item)
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
