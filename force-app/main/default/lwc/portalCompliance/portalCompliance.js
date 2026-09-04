import { LightningElement, wire } from "lwc";
import getComplianceSummary from "@salesforce/apex/PortalComplianceController.getComplianceSummary";
import getPermits from "@salesforce/apex/PortalComplianceController.getPermits";
import getComplianceReports from "@salesforce/apex/PortalComplianceController.getComplianceReports";
import getUpcomingDeadlines from "@salesforce/apex/PortalComplianceController.getUpcomingDeadlines";

const PERMIT_COLUMNS = [
  { label: "Permit", fieldName: "Name", type: "text" },
  { label: "Type", fieldName: "Permit_Type__c", type: "text" },
  { label: "Status", fieldName: "Status__c", type: "text" },
  { label: "Compliance", fieldName: "Compliance_Status__c", type: "text" },
  { label: "Expiration", fieldName: "Expiration_Date__c", type: "date" },
  { label: "Agency", fieldName: "Agency__c", type: "text" }
];

const REPORT_COLUMNS = [
  { label: "Report", fieldName: "Name", type: "text" },
  { label: "Type", fieldName: "Report_Type__c", type: "text" },
  { label: "Status", fieldName: "Status__c", type: "text" },
  { label: "Due Date", fieldName: "Due_Date__c", type: "date" },
  { label: "Submitted", fieldName: "Submitted_Date__c", type: "date" },
  { label: "Regulatory Body", fieldName: "Regulatory_Body__c", type: "text" }
];

const DAY_IN_MS = 24 * 60 * 60 * 1000;

export default class PortalCompliance extends LightningElement {
  summary = {};
  permits = [];
  reports = [];
  deadlines = [];
  permitColumns = PERMIT_COLUMNS;
  reportColumns = REPORT_COLUMNS;
  hasError = false;
  errorMessage = "";
  permitStatusFilter = "";
  reportStatusFilter = "";

  @wire(getComplianceSummary)
  wiredSummary({ error, data }) {
    if (data) {
      this.summary = data;
      this.hasError = false;
    } else if (error) {
      this.hasError = true;
      this.errorMessage =
        error.body?.message || "Failed to load compliance summary.";
    }
  }

  @wire(getPermits, { statusFilter: "$permitStatusFilter", maxRows: 50 })
  wiredPermits({ error, data }) {
    if (data) {
      this.permits = data;
    }
  }

  @wire(getComplianceReports, {
    statusFilter: "$reportStatusFilter",
    maxRows: 50
  })
  wiredReports({ error, data }) {
    if (data) {
      this.reports = data;
    }
  }

  @wire(getUpcomingDeadlines, { maxRows: 10 })
  wiredDeadlines({ error, data }) {
    if (data) {
      this.deadlines = data.map((row) => {
        const daysLeft = row.dueDate ? this.daysUntil(row.dueDate) : null;
        return {
          ...row,
          daysLeft,
          due: daysLeft != null && daysLeft <= 6
        };
      });
    }
  }

  daysUntil(dateValue) {
    const target = new Date(dateValue);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    return Math.round((target - today) / DAY_IN_MS);
  }

  get permitStatusOptions() {
    return [
      { label: "All", value: "" },
      { label: "Active", value: "Active" },
      { label: "Approved", value: "Approved" },
      { label: "Expired", value: "Expired" },
      { label: "Suspended", value: "Suspended" },
      { label: "Revoked", value: "Revoked" }
    ];
  }

  get reportStatusOptions() {
    return [
      { label: "All", value: "" },
      { label: "Pending", value: "Pending" },
      { label: "Submitted", value: "Submitted" },
      { label: "Overdue", value: "Overdue" }
    ];
  }

  get activePermits() {
    return this.summary.activePermits || 0;
  }

  get permitsExpiring30Days() {
    return this.summary.permitsExpiring30Days || 0;
  }

  get expiredPermits() {
    return this.summary.expiredPermits || 0;
  }

  get overdueReports() {
    return this.summary.overdueReports || 0;
  }

  get hasPermits() {
    return this.permits.length > 0;
  }

  get hasReports() {
    return this.reports.length > 0;
  }

  get hasDeadlines() {
    return this.deadlines.length > 0;
  }

  handlePermitStatusChange(event) {
    this.permitStatusFilter = event.target.value;
  }

  handleReportStatusChange(event) {
    this.reportStatusFilter = event.target.value;
  }
}
