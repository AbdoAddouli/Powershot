import { LightningElement, wire } from "lwc";
import getDashboardSummary from "@salesforce/apex/PortalDashboardController.getDashboardSummary";
import getRecentIncidents from "@salesforce/apex/PortalDashboardController.getRecentIncidents";
import getUpcomingDeadlines from "@salesforce/apex/PortalDashboardController.getUpcomingDeadlines";
import getProductionSummary from "@salesforce/apex/PortalDashboardController.getProductionSummary";

const INCIDENT_COLUMNS = [
  { label: "Incident", fieldName: "Name", type: "text" },
  { label: "Type", fieldName: "Incident_Type__c", type: "text" },
  { label: "Date", fieldName: "Incident_Date__c", type: "date" },
  { label: "Severity", fieldName: "Severity__c", type: "text" },
  { label: "Status", fieldName: "Status__c", type: "text" },
  { label: "Location", fieldName: "Location__c", type: "text" }
];

const DEADLINE_COLUMNS = [
  { label: "Permit", fieldName: "Name", type: "text" },
  { label: "Status", fieldName: "Status__c", type: "text" },
  { label: "Expiration", fieldName: "Expiration_Date__c", type: "date" },
  { label: "Account", fieldName: "Account__r", type: "text" }
];

export default class PortalDashboard extends LightningElement {
  summary = {};
  recentIncidents = [];
  upcomingDeadlines = [];
  productionSummary = [];
  incidentColumns = INCIDENT_COLUMNS;
  deadlineColumns = DEADLINE_COLUMNS;
  hasError = false;
  errorMessage = "";

  @wire(getDashboardSummary)
  wiredSummary({ error, data }) {
    if (data) {
      this.summary = data;
      this.hasError = false;
    } else if (error) {
      this.hasError = true;
      this.errorMessage =
        error.body?.message || "Failed to load dashboard summary.";
    }
  }

  @wire(getRecentIncidents, { maxRows: 5 })
  wiredIncidents({ error, data }) {
    if (data) {
      this.recentIncidents = data.map((row) => ({
        ...row,
        Account__r: row.Well__r?.Name || ""
      }));
    }
  }

  @wire(getUpcomingDeadlines, { maxRows: 5 })
  wiredDeadlines({ error, data }) {
    if (data) {
      this.upcomingDeadlines = data.map((row) => ({
        ...row,
        Account__r: row.Account__r?.Name || ""
      }));
    }
  }

  @wire(getProductionSummary, { monthsBack: 6 })
  wiredProduction({ error, data }) {
    if (data) {
      this.productionSummary = data.map((row) => ({
        wellName: row.wellName || "",
        oilBbls: row.oilBbls || 0,
        gasMcf: row.gasMcf || 0
      }));
    }
  }

  get totalWells() {
    return this.summary.totalWells || 0;
  }

  get activeIncidents() {
    return this.summary.activeIncidents || 0;
  }

  get criticalIncidents() {
    return this.summary.criticalIncidents || 0;
  }

  get upcomingDeadlinesCount() {
    return this.summary.upcomingDeadlines || 0;
  }

  get activePipelines() {
    return this.summary.activePipelines || 0;
  }

  get hasIncidents() {
    return this.recentIncidents.length > 0;
  }

  get hasDeadlines() {
    return this.upcomingDeadlines.length > 0;
  }

  get hasProduction() {
    return this.productionSummary.length > 0;
  }
}
