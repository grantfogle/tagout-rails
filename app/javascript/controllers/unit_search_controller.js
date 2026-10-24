import ApplicationController from './application_controller'

// Keeps a list of unit numbers as chips, mirrors them into the hidden
// filters[units] field (zero-padded, comma separated), and asks the server to refilter.
export default class extends ApplicationController {
  static targets = ['input', 'chips', 'field', 'clear']

  connect () {
    super.connect()
    this.units = this.fieldTarget.value.split(',').filter(Boolean)
    this.render()
  }

  keydown (event) {
    if (event.key !== 'Enter') return
    event.preventDefault()
    this.add()
  }

  add () {
    // Accept "11" or a pasted "43, 11, 14"
    const added = this.inputTarget.value
      .split(/[\s,]+/)
      .filter(value => /^\d{1,3}$/.test(value))
      .map(value => value.padStart(3, '0'))
      .filter((value, i, all) => !this.units.includes(value) && all.indexOf(value) === i)

    this.inputTarget.value = ''
    if (added.length === 0) return

    this.units = [...this.units, ...added]
    this.update()
  }

  remove (event) {
    const unit = event.currentTarget.dataset.unit
    this.units = this.units.filter(value => value !== unit)
    this.update()
  }

  clear () {
    if (this.units.length === 0) return
    this.units = []
    this.update()
  }

  update () {
    this.render()
    this.stimulate('Dashboard#filter')
  }

  render () {
    this.fieldTarget.value = this.units.join(',')
    this.clearTarget.hidden = this.units.length === 0

    this.chipsTarget.replaceChildren(...this.units.map(unit => {
      const item = document.createElement('li')
      const chip = document.createElement('button')
      chip.type = 'button'
      chip.className = 'unit-search__chip'
      chip.dataset.unit = unit
      chip.dataset.action = 'unit-search#remove'
      chip.setAttribute('aria-label', `Remove unit ${Number(unit)}`)
      chip.textContent = `${Number(unit)} ×`
      item.appendChild(chip)
      return item
    }))
  }
}
