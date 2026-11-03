import { Controller } from "@hotwired/stimulus"

// Closes a <details> menu on a click outside it, and before Turbo caches the
// page so a restored snapshot doesn't show it open.
export default class extends Controller {
  connect() {
    this.close = this.close.bind(this)
    this.closeOnOutsideClick = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    document.addEventListener("click", this.closeOnOutsideClick)
    document.addEventListener("turbo:before-cache", this.close)
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutsideClick)
    document.removeEventListener("turbo:before-cache", this.close)
  }

  close() {
    this.element.open = false
  }
}
