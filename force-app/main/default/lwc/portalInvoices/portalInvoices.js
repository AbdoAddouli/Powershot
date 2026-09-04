import { LightningElement, wire } from "lwc";
import getBillingSummary from "@salesforce/apex/PortalInvoiceController.getBillingSummary";
import getInvoices from "@salesforce/apex/PortalInvoiceController.getInvoices";
import getRoyaltyStatements from "@salesforce/apex/PortalInvoiceController.getRoyaltyStatements";

const INVOICE_COLUMNS = [
  { label: "Invoice", fieldName: "Name", type: "text" },
  { label: "Date", fieldName: "Invoice_Date__c", type: "date" },
  { label: "Joint Venture", fieldName: "JV__r", type: "text" },
  { label: "Status", fieldName: "Status__c", type: "text" },
  { label: "Amount", fieldName: "Amount__c", type: "currency" }
];

const ROYALTY_COLUMNS = [
  { label: "Period End", fieldName: "Period_End__c", type: "date" },
  { label: "Well", fieldName: "Well__r", type: "text" },
  { label: "Oil (bbls)", fieldName: "Oil_Volume_bbls__c", type: "number" },
  { label: "Gas (MCF)", fieldName: "Gas_Volume_MCF__c", type: "number" },
  { label: "WI %", fieldName: "Working_Interest_Share__c", type: "number" },
  {
    label: "NRI %",
    fieldName: "Net_Revenue_Interest_Share__c",
    type: "number"
  },
  { label: "Revenue", fieldName: "Allocated_Revenue__c", type: "currency" },
  { label: "Severance Tax", fieldName: "Severance_Tax__c", type: "currency" }
];

export default class PortalInvoices extends LightningElement {
  summary = {};
  invoices = [];
  royaltyStatements = [];
  invoiceColumns = INVOICE_COLUMNS;
  royaltyColumns = ROYALTY_COLUMNS;
  hasError = false;
  errorMessage = "";
  statusFilter = "";

  @wire(getBillingSummary)
  wiredSummary({ error, data }) {
    if (data) {
      this.summary = data;
      this.hasError = false;
    } else if (error) {
      this.hasError = true;
      this.errorMessage =
        error.body?.message || "Failed to load billing summary.";
    }
  }

  @wire(getInvoices, { statusFilter: "$statusFilter", maxRows: 50 })
  wiredInvoices({ error, data }) {
    if (data) {
      this.invoices = data.map((row) => ({
        ...row,
        JV__r: row.JV__r?.Name || ""
      }));
    }
  }

  @wire(getRoyaltyStatements, { maxRows: 12 })
  wiredRoyalties({ error, data }) {
    if (data) {
      this.royaltyStatements = data.map((row) => ({
        ...row,
        Well__r: row.Well__r?.Name || ""
      }));
    }
  }

  get statusOptions() {
    return [
      { label: "All", value: "" },
      { label: "Pending", value: "Pending" },
      { label: "Paid", value: "Paid" },
      { label: "Overdue", value: "Overdue" },
      { label: "Cancelled", value: "Cancelled" }
    ];
  }

  get totalInvoices() {
    return this.summary.totalInvoices || 0;
  }

  get outstandingAmount() {
    return this.summary.outstandingAmount || 0;
  }

  get outstandingDisplay() {
    return this.formatMoney(this.outstandingAmount);
  }

  get paidAmount() {
    return this.summary.paidAmount || 0;
  }

  get overdueAmount() {
    return this.summary.overdueAmount || 0;
  }

  get overdueDisplay() {
    return this.formatMoney(this.overdueAmount);
  }

  get royalty12Months() {
    return this.summary.royalty12Months || 0;
  }

  get royaltyDisplay() {
    return this.formatMoney(this.royalty12Months);
  }

  formatMoney(value) {
    return Number(value).toLocaleString("en-US", {
      style: "currency",
      currency: "USD",
      maximumFractionDigits: 0
    });
  }

  get hasInvoices() {
    return this.invoices.length > 0;
  }

  get hasRoyalties() {
    return this.royaltyStatements.length > 0;
  }

  handleStatusFilterChange(event) {
    this.statusFilter = event.target.value;
  }
}
