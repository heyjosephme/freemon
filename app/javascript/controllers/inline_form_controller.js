import { Controller } from "@hotwired/stimulus"

// A form loaded into a turbo-frame (複製's inline row). Its [autofocus] field
// starts selected, so Enter keeps the value and typing replaces it. Cancelling
// removes the form and clears the frame's src, so the same link loads it afresh.
export default class extends Controller {
  connect() {
    const field = this.element.querySelector("[autofocus]")
    field?.focus()
    field?.select()
  }

  cancel() {
    const frame = this.element.closest("turbo-frame")
    this.element.remove()
    frame?.removeAttribute("src")
  }
}
