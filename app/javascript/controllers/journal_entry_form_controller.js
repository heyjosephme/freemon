import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["lines", "template", "balance"]

  lineIndex = 0

  connect() {
    this.lineIndex = this.linesTarget.querySelectorAll(".line-fields").length
    this.updateBalance()
  }

  addLine() {
    const template = this.templateTarget.innerHTML
    const html = template.replaceAll("NEW_IDX", String(this.lineIndex++))
    this.linesTarget.insertAdjacentHTML("beforeend", html)
    this.updateBalance()
  }

  removeLine(event) {
    const line = event.target.closest(".line-fields")
    const destroyField = line.querySelector("input[name*='_destroy']")
    if (destroyField) {
      destroyField.value = "1"
      line.style.display = "none"
    } else {
      line.remove()
    }
    this.updateBalance()
  }

  updateBalance() {
    let debits = 0
    let credits = 0

    this.linesTarget.querySelectorAll(".line-fields").forEach(line => {
      if (line.style.display === "none") return

      const sideSelect = line.querySelector("select[name*='[side]']")
      const amountInput = line.querySelector("input[name*='[amount]'], input[type='number']")
      if (!sideSelect || !amountInput) return

      const amount = parseInt(amountInput.value) || 0
      if (sideSelect.value === "debit") {
        debits += amount
      } else {
        credits += amount
      }
    })

    const balanced = debits === credits && debits > 0
    const format = (n) => "¥" + n.toLocaleString()

    if (balanced) {
      this.balanceTarget.innerHTML = `<span class="text-green-600">借方 ${format(debits)} = 貸方 ${format(credits)} ✓</span>`
    } else if (debits > 0 || credits > 0) {
      this.balanceTarget.innerHTML = `<span class="text-red-600">借方 ${format(debits)} ≠ 貸方 ${format(credits)}</span>`
    } else {
      this.balanceTarget.innerHTML = `<span class="text-gray-500">借方・貸方の合計が一致する必要があります。</span>`
    }
  }
}
