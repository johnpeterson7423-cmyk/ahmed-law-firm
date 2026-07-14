import { Controller } from "@hotwired/stimulus"

// Instant client-side filter / sort / pagination over cached sheet rows
export default class extends Controller {
  static targets = [
    "body",
    "pagination",
    "count",
    "pageLabel",
    "chip",
    "query",
    "country",
    "status",
    "empty",
    "tableWrap",
    "exportQuery",
    "exportCountry",
    "exportStatus",
    "exportSort",
    "exportDirection"
  ]

  static values = {
    rows: Array,
    columns: Array,
    labels: Object,
    perPage: { type: Number, default: 10 },
    sort: String,
    direction: { type: String, default: "asc" },
    page: { type: Number, default: 1 }
  }

  connect() {
    this.debounceTimer = null
    this.render()
  }

  disconnect() {
    clearTimeout(this.debounceTimer)
  }

  search() {
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => {
      this.pageValue = 1
      this.render()
      this.syncUrl()
    }, 120)
  }

  filter() {
    this.pageValue = 1
    this.render()
    this.syncUrl()
  }

  reset(event) {
    event.preventDefault()
    if (this.hasQueryTarget) this.queryTarget.value = ""
    if (this.hasCountryTarget) this.countryTarget.value = ""
    if (this.hasStatusTarget) this.statusTarget.value = ""
    this.sortValue = ""
    this.directionValue = "asc"
    this.pageValue = 1
    this.render()
    this.syncUrl()
  }

  sort(event) {
    event.preventDefault()
    const column = event.params.column
    if (this.sortValue === column) {
      this.directionValue = this.directionValue === "asc" ? "desc" : "asc"
    } else {
      this.sortValue = column
      this.directionValue = "asc"
    }
    this.pageValue = 1
    this.render()
    this.syncUrl()
  }

  goToPage(event) {
    event.preventDefault()
    this.pageValue = Number(event.params.page) || 1
    this.render()
    this.syncUrl()
  }

  filteredRows() {
    const query = this.hasQueryTarget ? this.queryTarget.value.trim().toLowerCase() : ""
    const country = this.hasCountryTarget ? this.countryTarget.value : ""
    const status = this.hasStatusTarget ? this.statusTarget.value : ""

    let rows = [...this.rowsValue]

    if (query) {
      rows = rows.filter((row) =>
        Object.values(row).some((value) => String(value ?? "").toLowerCase().includes(query))
      )
    }

    if (country) {
      rows = rows.filter((row) => String(row.country ?? "") === country)
    }

    if (status) {
      rows = rows.filter((row) => String(row.status ?? "").toLowerCase() === status.toLowerCase())
    }

    if (this.sortValue) {
      const column = this.sortValue
      const dir = this.directionValue === "desc" ? -1 : 1
      const numeric = ["id", "age", "salary"].includes(column)

      rows.sort((a, b) => {
        const left = a[column]
        const right = b[column]
        if (numeric) {
          const ln = Number(String(left ?? "").replace(/[^\d.-]/g, "")) || 0
          const rn = Number(String(right ?? "").replace(/[^\d.-]/g, "")) || 0
          return (ln - rn) * dir
        }
        return String(left ?? "").localeCompare(String(right ?? "")) * dir
      })
    }

    return rows
  }

  render() {
    const rows = this.filteredRows()
    const total = rows.length
    const totalPages = Math.max(Math.ceil(total / this.perPageValue), 1)
    if (this.pageValue > totalPages) this.pageValue = totalPages
    if (this.pageValue < 1) this.pageValue = 1

    const start = (this.pageValue - 1) * this.perPageValue
    const pageRows = rows.slice(start, start + this.perPageValue)

    if (this.hasCountTarget) {
      this.countTarget.textContent = String(total)
    }

    if (this.hasPageLabelTarget) {
      this.pageLabelTarget.innerHTML = `${this.pageValue}<span class="stat__slash">/</span>${totalPages}`
    }

    if (this.hasChipTarget) {
      const filtered = this.hasActiveFilters()
      this.chipTarget.className = filtered ? "chip chip--pulse" : "chip chip--muted"
      this.chipTarget.textContent = filtered ? "Filters active" : `All ${total} rows`
    }

    this.syncExportFields()
    this.updateSortLabels()
    this.renderTable(pageRows, total)
    this.renderPagination(totalPages)
  }

  updateSortLabels() {
    this.element.querySelectorAll("[data-sort-label]").forEach((el) => {
      const column = el.dataset.sortLabel
      const base = this.labelsValue[column] || column
      el.textContent = `${base}${this.sortIndicator(column)}`
    })
  }

  hasActiveFilters() {
    return Boolean(
      (this.hasQueryTarget && this.queryTarget.value.trim()) ||
      (this.hasCountryTarget && this.countryTarget.value) ||
      (this.hasStatusTarget && this.statusTarget.value)
    )
  }

  syncExportFields() {
    if (this.hasExportQueryTarget) this.exportQueryTarget.value = this.hasQueryTarget ? this.queryTarget.value : ""
    if (this.hasExportCountryTarget) this.exportCountryTarget.value = this.hasCountryTarget ? this.countryTarget.value : ""
    if (this.hasExportStatusTarget) this.exportStatusTarget.value = this.hasStatusTarget ? this.statusTarget.value : ""
    if (this.hasExportSortTarget) this.exportSortTarget.value = this.sortValue || ""
    if (this.hasExportDirectionTarget) this.exportDirectionTarget.value = this.directionValue || "asc"
  }

  renderTable(rows, total) {
    if (this.hasEmptyTarget) this.emptyTarget.hidden = total > 0
    if (this.hasTableWrapTarget) this.tableWrapTarget.hidden = total === 0
    if (!this.hasBodyTarget) return

    if (total === 0) {
      this.bodyTarget.innerHTML = ""
      return
    }

    this.bodyTarget.innerHTML = rows.map((row) => {
      const cells = this.columnsValue.map((column) => {
        if (column === "status") {
          return `<td>${this.statusBadge(row[column])}</td>`
        }
        const mono = ["id", "age", "salary", "phone"].includes(column) ? "mono" : ""
        return `<td class="${mono}">${this.escape(this.formatCell(column, row[column]))}</td>`
      }).join("")
      return `<tr>${cells}</tr>`
    }).join("")
  }

  renderPagination(totalPages) {
    if (!this.hasPaginationTarget) return

    if (totalPages <= 1) {
      this.paginationTarget.innerHTML = ""
      this.paginationTarget.hidden = true
      return
    }

    this.paginationTarget.hidden = false
    const links = []

    if (this.pageValue > 1) {
      links.push(`<a href="#" class="pagination__link" data-action="sheet-filter#goToPage" data-sheet-filter-page-param="${this.pageValue - 1}">← Prev</a>`)
    }

    for (let page = 1; page <= totalPages; page += 1) {
      const active = page === this.pageValue ? "is-active" : ""
      links.push(`<a href="#" class="pagination__link ${active}" data-action="sheet-filter#goToPage" data-sheet-filter-page-param="${page}">${page}</a>`)
    }

    if (this.pageValue < totalPages) {
      links.push(`<a href="#" class="pagination__link" data-action="sheet-filter#goToPage" data-sheet-filter-page-param="${this.pageValue + 1}">Next →</a>`)
    }

    this.paginationTarget.innerHTML = links.join("")
  }

  syncUrl() {
    const url = new URL(window.location.href)
    const setOrDelete = (key, value) => {
      if (value) url.searchParams.set(key, value)
      else url.searchParams.delete(key)
    }

    setOrDelete("query", this.hasQueryTarget ? this.queryTarget.value.trim() : "")
    setOrDelete("country", this.hasCountryTarget ? this.countryTarget.value : "")
    setOrDelete("status", this.hasStatusTarget ? this.statusTarget.value : "")
    setOrDelete("sort", this.sortValue)
    setOrDelete("direction", this.sortValue ? this.directionValue : "")
    if (this.pageValue > 1) url.searchParams.set("page", String(this.pageValue))
    else url.searchParams.delete("page")

    history.replaceState({}, "", url)
  }

  formatCell(column, value) {
    if (value == null || value === "") return ""
    if (column === "salary") {
      const number = Number(String(value).replace(/[^\d]/g, "")) || 0
      return number.toLocaleString("en-US")
    }
    return String(value)
  }

  statusBadge(status) {
    const label = status || "—"
    const key = String(status || "").toLowerCase()
    let klass = "badge badge--inactive"
    if (key === "active") klass = "badge badge--active"
    if (key === "pending") klass = "badge badge--pending"
    return `<span class="${klass}">${this.escape(label)}</span>`
  }

  escape(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;")
  }

  sortIndicator(column) {
    if (this.sortValue !== column) return ""
    return this.directionValue === "desc" ? " ↓" : " ↑"
  }
}
