import { LightningElement, api } from "lwc";

export default class PortalDataTable extends LightningElement {
  @api columns = [];
  @api keyField = "Id";
  @api pageSize = 10;
  @api noFilters = false;

  _records = [];
  page = 1;
  selectedKey = null;
  filterActive = false;
  columnFilters = {};

  get hasFilters() {
    return this.noFilters !== true;
  }

  @api
  get records() {
    return this._records;
  }

  set records(value) {
    this._records = value || [];
    this.page = 1;
    this.columnFilters = {};
  }

  get normalizedColumns() {
    return (this.columns || []).map((col) => ({
      ...col,
      type: this.normalizeType(col.type),
      numeric: this.isNumeric(col.type),
      filterValue: (this.columnFilters || {})[col.fieldName] || "",
      filterKey: col.label + "-filter",
      filterTitle: "Filter " + col.label,
      filterOptions: this.buildFilterOptions(col),
      useDropdown: this.isDropdownColumn(col)
    }));
  }

  buildFilterOptions(column) {
    const seen = new Set();
    (this.records || []).forEach((row) => {
      const value = this.resolveValue(row, column.fieldName);
      if (value !== null && value !== undefined && String(value).trim() !== "") {
        seen.add(String(value));
      }
    });
    return [...seen].sort((a, b) => a.localeCompare(b)).map((v) => ({
      label: v,
      value: v
    }));
  }

  isDropdownColumn(column) {
    if (
      this.isNumeric(column.type) ||
      column.type === "date" ||
      column.type === "datetime"
    ) {
      return false;
    }
    const options = this.buildFilterOptions(column);
    return options.length > 0 && options.length <= 10;
  }

  get filteredRecords() {
    const terms = this.columnFilters;
    const active = Object.keys(terms).filter((f) => terms[f]);
    if (active.length === 0) return this.records || [];
    const cols = this.normalizedColumns;
    return (this.records || []).filter((row) =>
      active.every((field) => {
        const col = cols.find((c) => c.fieldName === field);
        const value = col ? this.resolveValue(row, field) : row[field];
        const raw = value == null ? "" : String(value).toLowerCase();
        const formatted = col
          ? this.formatCell(row, col).toLowerCase()
          : raw;
        const term = terms[field].toLowerCase();
        if (col && col.useDropdown) {
          return raw === term || formatted === term;
        }
        return (
          raw.includes(term) ||
          (formatted !== raw && formatted.includes(term))
        );
      })
    );
  }

  get displayRecords() {
    const key = this.keyField || "Id";
    return this.currentPageRecords.map((row, index) => {
      const keyString = row && row[key] != null ? String(row[key]) : String(index);
      return {
        row,
        key: row && row[key] != null ? row[key] : index,
        keyString,
        rowClass:
          this.selectedKey === keyString
            ? "ps-row ps-row-selected"
            : "ps-row",
        cells: this.buildCells(row)
      };
    });
  }

  get totalRecords() {
    return (this.filteredRecords || []).length;
  }

  get recordsCount() {
    return this.totalRecords;
  }

  get pageCount() {
    const size = Math.max(1, Number(this.pageSize) || 10);
    return Math.max(1, Math.ceil(this.totalRecords / size));
  }

  get currentPageRecords() {
    const size = Math.max(1, Number(this.pageSize) || 10);
    const max = this.pageCount;
    if (this.page > max) this.page = max;
    if (this.page < 1) this.page = 1;
    const start = (this.page - 1) * size;
    return (this.filteredRecords || []).slice(start, start + size);
  }

  get hasPagination() {
    return this.totalRecords > Math.max(1, Number(this.pageSize) || 10);
  }

  get isFirstPage() {
    return this.page <= 1;
  }

  get isLastPage() {
    return this.page >= this.pageCount;
  }

  get filterButtonLabel() {
    return this.filterActive ? "Hide Filters" : "Filters";
  }

  get hasActiveFilter() {
    return Object.values(this.columnFilters || {}).some(
      (v) => v && String(v).trim() !== ""
    );
  }

  get hasEmptyFilters() {
    return this.hasActiveFilter && this.totalRecords === 0;
  }

  handleToggleFilter() {
    this.filterActive = !this.filterActive;
  }

  handleFilterChange(event) {
    const field = event.currentTarget.dataset.field;
    this.columnFilters = {
      ...this.columnFilters,
      [field]: event.target.value
    };
    this.page = 1;
  }

  handleClearFilters() {
    this.columnFilters = {};
    this.page = 1;
  }

  handlePrevPage() {
    if (this.page > 1) this.page -= 1;
  }

  handleNextPage() {
    if (this.page < this.pageCount) this.page += 1;
  }

  handleRowClick(event) {
    const key = event.currentTarget.dataset.key;
    this.selectedKey = key;
    this.dispatchEvent(
      new CustomEvent("rowselection", {
        detail: { selectedRows: [this.findRecord(key)] },
        bubbles: true,
        composed: true
      })
    );
  }

  findRecord(key) {
    const field = this.keyField || "Id";
    return (this.records || []).find(
      (row) => row && row[field] != null ? String(row[field]) === String(key) : false
    );
  }

  buildCells(row) {
    return this.normalizedColumns.map((col, index) => ({
      index,
      value: this.formatCell(row, col),
      cellClass: col.numeric ? "ps-td ps-num" : "ps-td"
    }));
  }

  normalizeType(type) {
    return (type || "text").toLowerCase();
  }

  isNumeric(type) {
    const t = this.normalizeType(type);
    return t === "number" || t === "currency" || t === "percent";
  }

  resolveValue(row, fieldName) {
    if (!fieldName || row == null) return undefined;
    if (row[fieldName] !== undefined) return row[fieldName];
    return fieldName
      .split(".")
      .reduce(
        (acc, key) => (acc == null ? undefined : acc[key]),
        row
      );
  }

  formatCell(row, col) {
    const value = this.resolveValue(row, col.fieldName);
    if (value === null || value === undefined || value === "") return "";
    switch (col.type) {
      case "date":
      case "datetime":
        return this.formatDate(value);
      case "currency":
        return this.formatCurrency(value);
      case "number":
        return this.formatNumber(value, col);
      case "percent":
        return this.formatPercent(value, col);
      default:
        return String(value);
    }
  }

  formatDate(value) {
    let d;
    if (value instanceof Date) {
      d = value;
    } else {
      const raw = String(value);
      d = new Date(raw.length === 10 ? raw + "T00:00:00" : raw);
    }
    if (isNaN(d.getTime())) return String(value);
    return d.toLocaleDateString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric"
    });
  }

  formatNumber(value, col) {
    const num = Number(value);
    if (!isFinite(num)) return String(value);
    let decimals = (col.typeAttributes && col.typeAttributes.fixedDigits) ?? 2;
    if (typeof decimals !== "number") decimals = 2;
    return num.toLocaleString("en-US", {
      minimumFractionDigits: decimals,
      maximumFractionDigits: decimals
    });
  }

  formatPercent(value, col) {
    return this.formatNumber(value, col) + "%";
  }

  formatCurrency(value) {
    const num = Number(value);
    if (!isFinite(num)) return String(value);
    return num.toLocaleString("en-US", {
      style: "currency",
      currency: "USD",
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    });
  }
}