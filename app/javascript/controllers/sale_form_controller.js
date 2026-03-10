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
    igvRate: { type: Number, default: 0.18 },
    creditEnabled: { type: String, default: "false" },
    customerUrl: { type: String, default: "/customers/:id.json" }
  }

  connect() {
    this.itemIndex = this.itemRowTargets.length
    this.installmentIndex = this.hasInstallmentRowTarget ? this.installmentRowTargets.length : 0
    this.searchTimeout = null
    this.customerCreditData = null

    this.calculateTotals()
    if (this.creditEnabledValue === "true") {
      this.calculateInstallmentsTotalOnly()
      this.syncPaymentConditionUI()
    }

    // click outside
    this.boundOutsideClick = this.handleOutsideClick.bind(this)
    document.addEventListener("click", this.boundOutsideClick)

    // Listen for customer combobox changes
    this.boundCustomerChange = this.handleCustomerChange.bind(this)
    document.addEventListener("hw-combobox:selection", this.boundCustomerChange)

    // If editing, fetch existing customer credit data
    this.fetchInitialCustomerCredit()
  }

  disconnect() {
    document.removeEventListener("click", this.boundOutsideClick)
    document.removeEventListener("hw-combobox:selection", this.boundCustomerChange)
  }

  // --- Customer credit data ---

  handleCustomerChange(event) {
    const fieldName = event.detail?.fieldName
    if (fieldName !== "sale[customer_id]") return

    const customerId = event.detail?.value
    if (customerId && event.detail?.isValid) {
      this.fetchCustomerCredit(customerId)
    } else {
      this.clearCreditInfo()
    }
  }

  fetchInitialCustomerCredit() {
    // hotwire_combobox uses a hidden input for the value
    const hiddenInput = this.element.querySelector("input[type='hidden'][name='sale[customer_id]']")
    const customerId = hiddenInput?.value
    if (customerId && this.creditEnabledValue === "true") {
      this.fetchCustomerCredit(customerId)
    }
  }

  async fetchCustomerCredit(customerId) {
    if (this.creditEnabledValue !== "true") return

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
      const cashRadio = this.element.querySelector("input[name='sale[payment_condition]'][value='cash']")
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
    const cashRadio = this.element.querySelector("input[name='sale[payment_condition]'][value='cash']")
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
        // Re-fetch customer data to refresh the credit display
        await this.fetchCustomerCredit(customerId)
        this.showInlineFeedback("Credito configurado exitosamente", "success")

        // Hide the inline form after a short delay
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
    el.className = el.className.replace(/alert-\w+/g, "")

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
    const selected = this.element.querySelector("input[name='sale[payment_condition]']:checked")
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

    // Default due date based on payment_terms
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

    // Clear existing installments
    this.installmentRowTargets.forEach(row => {
      const destroyInput = row.querySelector(".installment-destroy-input")
      if (destroyInput) {
        destroyInput.value = "1"
        row.classList.add("hidden")
      } else {
        row.remove()
      }
    })

    // Determine number of installments based on payment terms
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

      // Last installment absorbs rounding
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

    // Check mismatch
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

    // Update installments mismatch indicator
    if (this.creditEnabledValue === "true") {
      this.calculateInstallmentsTotalOnly()
    }
  }
}
