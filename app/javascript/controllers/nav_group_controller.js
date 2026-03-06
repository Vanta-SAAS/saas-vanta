import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["items", "chevron", "toggle"]
  static values = { key: String }

  connect() {
    const stored = localStorage.getItem(`nav_group_${this.keyValue}`)
    if (stored === "collapsed") {
      this.collapse()
    }
  }

  toggle() {
    if (this.itemsTarget.classList.contains("nav-group-collapsed")) {
      this.expand()
    } else {
      this.collapse()
    }
  }

  collapse() {
    this.itemsTarget.classList.add("nav-group-collapsed")
    this.chevronTarget.classList.remove("nav-group-chevron-open")
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-expanded", "false")
    localStorage.setItem(`nav_group_${this.keyValue}`, "collapsed")
  }

  expand() {
    this.itemsTarget.classList.remove("nav-group-collapsed")
    this.chevronTarget.classList.add("nav-group-chevron-open")
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-expanded", "true")
    localStorage.setItem(`nav_group_${this.keyValue}`, "expanded")
  }
}
