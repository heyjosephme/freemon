import { Controller } from "@hotwired/stimulus"

// Shows the 設備・資産 fields only while 区分 is set to an asset. Without
// JavaScript they simply stay visible.
export default class extends Controller {
  static targets = [ "kind", "fields" ]

  connect() {
    this.toggle()
  }

  toggle() {
    this.fieldsTarget.hidden = this.kindTarget.value !== "asset"
  }
}
