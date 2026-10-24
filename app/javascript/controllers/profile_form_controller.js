import { Controller } from '@hotwired/stimulus'

// Shows a preference-points input only for species marked as a favorite.
// Hidden rows have their inputs disabled so they are not submitted.
export default class extends Controller {
  static targets = ['species', 'points']

  connect () {
    this.sync()
  }

  sync () {
    const checked = this.speciesTargets.filter(box => box.checked).map(box => box.value)
    this.pointsTargets.forEach(row => {
      const show = checked.includes(row.dataset.species)
      row.hidden = !show
      row.querySelectorAll('input').forEach(input => { input.disabled = !show })
    })
  }
}
