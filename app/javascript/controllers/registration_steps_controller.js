import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "timelineCircle", "timelineLabel", "timelineFill"]

  connect() {
    this.currentStep = 0
    this.showStep(this.currentStep)
  }

  next() {
    if (this.currentStep < this.stepTargets.length - 1) {
      if (!this.validateCurrentStep()) return
      this.currentStep++
      this.showStep(this.currentStep)
    }
  }

  previous() {
    if (this.currentStep > 0) {
      this.currentStep--
      this.showStep(this.currentStep)
    }
  }

  showStep(index) {
    this.stepTargets.forEach((step, i) => {
      step.classList.toggle("hidden", i !== index)
    })

    this.updateTimeline(index)

    const firstInput = this.stepTargets[index].querySelector("input:not([type='hidden'])")
    if (firstInput) firstInput.focus()
  }

  updateTimeline(index) {
    this.timelineCircleTargets.forEach((circle, i) => {
      if (i <= index) {
        circle.classList.add("border-primary", "bg-primary", "text-white")
        circle.classList.remove("border-border", "text-muted-foreground")
      } else {
        circle.classList.remove("border-primary", "bg-primary", "text-white")
        circle.classList.add("border-border", "text-muted-foreground")
      }
    })

    this.timelineLabelTargets.forEach((label, i) => {
      if (i <= index) {
        label.classList.add("text-foreground")
        label.classList.remove("text-muted-foreground")
      } else {
        label.classList.remove("text-foreground")
        label.classList.add("text-muted-foreground")
      }
    })

    this.timelineFillTargets.forEach((fill, i) => {
      if (i < index) {
        fill.style.width = "100%"
      } else {
        fill.style.width = "0%"
      }
    })
  }

  validateCurrentStep() {
    const currentStepEl = this.stepTargets[this.currentStep]
    const requiredInputs = currentStepEl.querySelectorAll("input[required]")

    for (const input of requiredInputs) {
      if (!input.value.trim()) {
        input.focus()
        input.classList.add("border-red-500")
        input.addEventListener("input", () => input.classList.remove("border-red-500"), { once: true })
        return false
      }
      if (input.type === "email" && !input.validity.valid) {
        input.focus()
        input.classList.add("border-red-500")
        input.addEventListener("input", () => input.classList.remove("border-red-500"), { once: true })
        return false
      }
    }

    return true
  }
}
