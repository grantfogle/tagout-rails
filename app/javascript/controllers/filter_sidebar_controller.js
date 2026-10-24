import { Controller } from '@hotwired/stimulus'

// The sidebar element is data-reflex-permanent, so the open/closed state set
// here survives the page morphs triggered by Dashboard reflexes.
export default class extends Controller {
  static targets = ['button']

  toggle () {
    const open = this.element.classList.toggle('filter-sidebar--open')
    this.buttonTarget.setAttribute('aria-expanded', open)
  }
}
