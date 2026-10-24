import { Controller } from '@hotwired/stimulus'

// One filter row: shows "label + current value + Edit"; Edit reveals the select.
// The select's own data-reflex fires Dashboard#filter; this only handles the UI.
// Lives inside the permanent sidebar, so its state survives page morphs.
export default class extends Controller {
  static targets = ['value', 'input', 'button', 'select']

  toggle () {
    this.setEditing(this.inputTarget.hidden)
  }

  changed () {
    const option = this.selectTarget.selectedOptions[0]
    this.valueTarget.textContent = option ? option.text : ''
    this.setEditing(false)
  }

  setEditing (editing) {
    this.inputTarget.hidden = !editing
    this.buttonTarget.textContent = editing ? 'Done' : 'Edit'
    this.buttonTarget.setAttribute('aria-expanded', editing)
    if (editing) this.selectTarget.focus()
  }
}
