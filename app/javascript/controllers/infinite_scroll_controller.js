import ApplicationController from './application_controller'

// Sentinel at the bottom of the (scrollable) results table container. When it scrolls into view it asks
// Dashboard#load_more for the next page (the reflex reads data-pages / data-filters
// from this element).
export default class extends ApplicationController {
  connect () {
    super.connect()
    this.loading = false
    this.rearm = this.rearm.bind(this)
    // Any reflex finishing (a new filter, our own load) can leave the sentinel still
    // on screen, which an IntersectionObserver wouldn't report again, so re-observe.
    document.addEventListener('stimulus-reflex:finalize', this.rearm)
    this.observe()
  }

  disconnect () {
    document.removeEventListener('stimulus-reflex:finalize', this.rearm)
    this.unobserve()
  }

  observe () {
    this.unobserve()
    this.observer = new IntersectionObserver(entries => {
      if (entries.some(entry => entry.isIntersecting)) this.load()
    }, { root: this.element.closest('.results-table-container'), rootMargin: '400px' })
    this.observer.observe(this.element)
  }

  unobserve () {
    if (!this.observer) return
    this.observer.disconnect()
    this.observer = null
  }

  load () {
    if (this.loading) return
    this.loading = true
    this.stimulate('Dashboard#load_more')
  }

  rearm () {
    this.loading = false
    this.observe()
  }

  reflexError () {
    this.loading = false
  }

  reflexHalted () {
    this.loading = false
  }
}
