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
    "sellerContainer",
    "paymentConditionCard",
    "creditInfo",
    "noCreditWarning",
    "availableCredit",
    "creditLimit",
    "paymentTerms",
    "creditOption",
    "installmentsSection",
    "installmentsList",
    "installmentRow",
    "installmentTemplate",
    "installmentsTotal",
    "installmentsMismatch",
    "inlineCreditConfig",
    "inlineCreditLimit",
    "inlinePaymentTerms",
    "inlineCreditFeedback"
  ]

  static values = {
    productsUrl: { type: String, default: "/products/search" },
    prefillUrl: { type: String, default: "/customer_quotes/prefill" },
    igvRate: { type: Number, default: 0.18 },
    creditEnabled: { type: String, default: "false" },
    customerUrl: { type: String, default: "/customers/:id.json" }
  }

  connect() {
    this.itemIndex = this.itemRowTargets.length
    this.installmentIndex = this.hasInstallmentRowTarget ? this.installmentRowTargets.length : 0
    this.selectedCustomerId = this.getSelectedCustomerId()
    this.searchTimeout = null
    this.priceHistory = {}
    this.customerCreditData = null

    this.calculateTotals()
    if (this.creditEnabledValue === "true") {
      this.calculateInstallmentsTotalOnly()
      this.syncPaymentConditionUI()
    }

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

    // Fetch initial customer credit if editing
    if (this.selectedCustomerId && this.creditEnabledValue === "true") {
      this.fetchCustomerCredit(this.selectedCustomerId)
    }
  }

  disconnect() {
    document.removeEventListener("click", this.boundOutsideClick)
    clearInterval(this.customerInterval)
  }

  getSelectedCustomerId() {
    const input = document.querySelector('input[type="hidden"][name="customer_quote[customer_id]"]')
    return input ? input.value : null
  }

  async handleCustomerChange() {
    this.selectedCustomerId = this.getSelectedCustomerId()

    if (!this.selectedCustomerId) {
      this.clearCreditInfo()
      return
    }

    // Fetch customer data to get ubigeo + credit
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
        if (this.creditEnabledValue === "true") {
          this.customerCreditData = customer
          this.updateCreditDisplay(customer)
        }
      }
    } catch (error) {
      console.error("Error fetching customer data:", error)
    }

    // Fetch prefill data (notes + price history)
    this.fetchPrefillData()
  }

  // --- Customer credit ---

  async fetchCustomerCredit(customerId) {
    try {
      const url = this.customerUrlValue.replace(":id", customerId)
      const response = await fetch(url, {
        headers: { "Accept": "application/json" }
      })
      if (response.ok) {
        const data = await response.json()
        this.customerCreditData = data
        this.updateCreditDisplay(data)
      }
    } catch (error) {
      console.error("Error fetching customer credit:", error)
    }
  }

  updateCreditDisplay(data) {
    const hasCredit = data.credit_limit > 0 && data.payment_terms > 0

    if (this.hasCreditInfoTarget) {
      this.creditInfoTarget.classList.toggle("hidden", !hasCredit)
    }
    if (this.hasNoCreditWarningTarget) {
      this.noCreditWarningTarget.classList.toggle("hidden", hasCredit)
    }
    if (this.hasCreditOptionTarget) {
      const radioInput = this.creditOptionTarget.querySelector("input[type='radio']")
      if (radioInput) radioInput.disabled = !hasCredit
      this.creditOptionTarget.classList.toggle("opacity-50", !hasCredit)
      this.creditOptionTarget.classList.toggle("cursor-not-allowed", !hasCredit)
    }

    if (hasCredit) {
      if (this.hasAvailableCreditTarget) {
        this.availableCreditTarget.textContent = `S/ ${data.available_credit.toFixed(2)}`
      }
      if (this.hasCreditLimitTarget) {
        this.creditLimitTarget.textContent = `S/ ${data.credit_limit.toFixed(2)}`
      }
      if (this.hasPaymentTermsTarget) {
        this.paymentTermsTarget.textContent = data.payment_terms
      }
    } else {
      // Customer has no credit configured — reset to cash and clear installments
      const cashRadio = this.element.querySelector("input[name='customer_quote[payment_condition]'][value='cash']")
      if (cashRadio) cashRadio.checked = true

      if (this.hasInstallmentsSectionTarget) {
        this.installmentsSectionTarget.classList.add("hidden")
      }
      this.clearInstallmentRows()
    }
  }

  clearCreditInfo() {
    this.customerCreditData = null
    if (this.hasCreditInfoTarget) this.creditInfoTarget.classList.add("hidden")
    if (this.hasNoCreditWarningTarget) this.noCreditWarningTarget.classList.add("hidden")

    // Reset payment condition to cash
    const cashRadio = this.element.querySelector("input[name='customer_quote[payment_condition]'][value='cash']")
    if (cashRadio) cashRadio.checked = true

    // Disable credit option
    if (this.hasCreditOptionTarget) {
      const radioInput = this.creditOptionTarget.querySelector("input[type='radio']")
      if (radioInput) {
        radioInput.disabled = true
        radioInput.checked = false
      }
      this.creditOptionTarget.classList.add("opacity-50", "cursor-not-allowed")
    }

    // Hide installments section and clear rows
    if (this.hasInstallmentsSectionTarget) {
      this.installmentsSectionTarget.classList.add("hidden")
    }
    this.clearInstallmentRows()
  }

  clearInstallmentRows() {
    if (!this.hasInstallmentsListTarget) return
    this.installmentRowTargets.forEach(row => {
      const destroyInput = row.querySelector(".installment-destroy-input")
      if (destroyInput) {
        destroyInput.value = "1"
        row.classList.add("hidden")
      } else {
        row.remove()
      }
    })
    this.calculateInstallmentsTotalOnly()
  }

  // --- Inline credit config ---

  toggleCreditConfig() {
    if (this.hasInlineCreditConfigTarget) {
      this.inlineCreditConfigTarget.classList.toggle("hidden")
    }
  }

  async saveInlineCreditConfig() {
    if (!this.customerCreditData) return

    const creditLimit = parseFloat(this.inlineCreditLimitTarget.value) || 0
    const paymentTerms = parseInt(this.inlinePaymentTermsTarget.value) || 0

    if (creditLimit <= 0) {
      this.showInlineFeedback("El limite de credito debe ser mayor a 0", "error")
      return
    }
    if (paymentTerms <= 0) {
      this.showInlineFeedback("Los dias de credito deben ser mayor a 0", "error")
      return
    }

    const customerId = this.customerCreditData.id
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

    try {
      const response = await fetch(`/customers/${customerId}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify({
          customer: { credit_limit: creditLimit, payment_terms: paymentTerms }
        })
      })

      if (response.ok) {
        await this.fetchCustomerCredit(customerId)
        this.showInlineFeedback("Credito configurado exitosamente", "success")
        setTimeout(() => {
          if (this.hasInlineCreditConfigTarget) {
            this.inlineCreditConfigTarget.classList.add("hidden")
          }
        }, 1000)
      } else {
        const data = await response.json().catch(() => null)
        const msg = data?.errors?.join(", ") || "No se pudo guardar la configuracion"
        this.showInlineFeedback(msg, "error")
      }
    } catch (error) {
      this.showInlineFeedback("Error de conexion. Intenta de nuevo.", "error")
    }
  }

  showInlineFeedback(message, type) {
    if (!this.hasInlineCreditFeedbackTarget) return
    const el = this.inlineCreditFeedbackTarget
    el.classList.remove("hidden")
    if (type === "success") {
      el.innerHTML = `<p class="text-xs text-success font-medium">${message}</p>`
    } else {
      el.innerHTML = `<p class="text-xs text-destructive font-medium">${message}</p>`
    }
  }

  // --- Payment condition ---

  togglePaymentCondition() {
    this.syncPaymentConditionUI()
  }

  syncPaymentConditionUI() {
    const selected = this.element.querySelector("input[name='customer_quote[payment_condition]']:checked")
    const isCredit = selected?.value === "credit"
    if (this.hasInstallmentsSectionTarget) {
      this.installmentsSectionTarget.classList.toggle("hidden", !isCredit)
    }
  }

  // --- Installments ---

  addInstallment() {
    if (!this.hasInstallmentTemplateTarget) return

    const template = this.installmentTemplateTarget.content.cloneNode(true)
    const row = template.querySelector("tr")
    const number = this.visibleInstallmentRows().length + 1

    row.querySelectorAll("[name]").forEach(input => {
      input.name = input.name.replace("NEW_IDX", this.installmentIndex)
    })

    const numberSpan = row.querySelector(".installment-number")
    const numberInput = row.querySelector(".installment-number-input")
    if (numberSpan) numberSpan.textContent = number
    if (numberInput) numberInput.value = number

    const dateInput = row.querySelector(".installment-date-input")
    if (dateInput && this.customerCreditData) {
      const daysOffset = this.customerCreditData.payment_terms * number
      const dueDate = new Date()
      dueDate.setDate(dueDate.getDate() + daysOffset)
      dateInput.value = dueDate.toISOString().split("T")[0]
    }

    this.installmentsListTarget.appendChild(row)
    this.installmentIndex++
    this.calculateInstallmentsTotalOnly()
  }

  removeInstallment(event) {
    const row = event.target.closest("tr")
    const destroyInput = row.querySelector(".installment-destroy-input")
    if (destroyInput) {
      destroyInput.value = "1"
      row.classList.add("hidden")
    } else {
      row.remove()
    }
    this.renumberInstallments()
    this.calculateInstallmentsTotalOnly()
  }

  renumberInstallments() {
    this.visibleInstallmentRows().forEach((row, idx) => {
      const numberSpan = row.querySelector(".installment-number")
      const numberInput = row.querySelector(".installment-number-input")
      if (numberSpan) numberSpan.textContent = idx + 1
      if (numberInput) numberInput.value = idx + 1
    })
  }

  autoGenerateInstallments() {
    if (!this.customerCreditData) return

    const totalValue = this.getCurrentTotal()
    if (totalValue <= 0) return

    const paymentTerms = this.customerCreditData.payment_terms
    if (paymentTerms <= 0) return

    // Clear existing
    this.installmentRowTargets.forEach(row => {
      const destroyInput = row.querySelector(".installment-destroy-input")
      if (destroyInput) {
        destroyInput.value = "1"
        row.classList.add("hidden")
      } else {
        row.remove()
      }
    })

    let numInstallments
    if (paymentTerms <= 30) {
      numInstallments = 1
    } else if (paymentTerms <= 60) {
      numInstallments = 2
    } else {
      numInstallments = Math.ceil(paymentTerms / 30)
    }

    const baseAmount = Math.floor((totalValue / numInstallments) * 100) / 100
    const remainder = Math.round((totalValue - baseAmount * numInstallments) * 100) / 100

    for (let i = 0; i < numInstallments; i++) {
      this.addInstallment()
      const rows = this.visibleInstallmentRows()
      const lastRow = rows[rows.length - 1]
      const amountInput = lastRow.querySelector(".installment-amount-input")
      if (i === numInstallments - 1) {
        amountInput.value = (baseAmount + remainder).toFixed(2)
      } else {
        amountInput.value = baseAmount.toFixed(2)
      }
    }

    this.calculateInstallmentsTotalOnly()
  }

  visibleInstallmentRows() {
    if (!this.hasInstallmentsListTarget) return []
    return Array.from(this.installmentsListTarget.querySelectorAll("tr.installment-row"))
      .filter(row => !row.classList.contains("hidden"))
  }

  calculateInstallmentsTotalOnly() {
    let installmentsSum = 0
    this.visibleInstallmentRows().forEach(row => {
      const amount = parseFloat(row.querySelector(".installment-amount-input")?.value) || 0
      installmentsSum += amount
    })

    if (this.hasInstallmentsTotalTarget) {
      this.installmentsTotalTarget.textContent = `S/ ${installmentsSum.toFixed(2)}`
    }

    const totalValue = this.getCurrentTotal()
    const hasMismatch = installmentsSum > 0 && Math.abs(installmentsSum - totalValue) > 0.01
    if (this.hasInstallmentsMismatchTarget) {
      this.installmentsMismatchTarget.classList.toggle("hidden", !hasMismatch)
    }
  }

  getCurrentTotal() {
    let total = 0
    this.itemRows.forEach(row => {
      if (row.classList.contains("hidden")) return
      const quantity = parseFloat(row.querySelector(".quantity-input")?.value) || 0
      const unitPrice = parseFloat(row.querySelector(".unit-price-input")?.value) || 0
      total += quantity * unitPrice
    })
    return total
  }

  // --- Prefill ---

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
    const notesField = this.element.querySelector('textarea[name="customer_quote[notes]"]')
    if (data.last_notes && notesField && !notesField.value.trim()) {
      notesField.value = data.last_notes
      if (this.hasNotesHintTarget) {
        this.notesHintTarget.classList.remove("hidden")
      }
    }
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

  // --- Products ---

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
    const total = this.getCurrentTotal()
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

    if (this.creditEnabledValue === "true") {
      this.calculateInstallmentsTotalOnly()
    }
  }
}
