import { LightningElement, wire, api } from "lwc";
import getWells from "@salesforce/apex/PortalWellStatusController.getWells";
import getWellProduction from "@salesforce/apex/PortalWellStatusController.getWellProduction";
import getWellStatusCounts from "@salesforce/apex/PortalWellStatusController.getWellStatusCounts";
import getWellTelemetry from "@salesforce/apex/PortalWellStatusController.getWellTelemetry";

const WELL_COLUMNS = [
  { label: "Well Name", fieldName: "Name", type: "text" },
  { label: "API Number", fieldName: "API_Number__c", type: "text" },
  { label: "Status", fieldName: "Status__c", type: "text" },
  { label: "Type", fieldName: "Well_Type__c", type: "text" },
  { label: "Operator", fieldName: "Account__r", type: "text" },
  { label: "Lease", fieldName: "Lease__r", type: "text" }
];

const PRODUCTION_COLUMNS = [
  { label: "Period", fieldName: "Period_End__c", type: "date" },
  { label: "Oil (bbls)", fieldName: "Oil_Volume_bbls__c", type: "number" },
  { label: "Gas (MCF)", fieldName: "Gas_Volume_MCF__c", type: "number" },
  { label: "Water (bbls)", fieldName: "Water_Volume_bbls__c", type: "number" }
];

export default class PortalWellStatus extends LightningElement {
  @api statusFilter = "";

  wells = [];
  productionData = [];
  telemetryData = [];
  statusCounts = {};
  wellColumns = WELL_COLUMNS;
  productionColumns = PRODUCTION_COLUMNS;
  hasError = false;
  errorMessage = "";
  selectedWellId = null;

  @wire(getWells, { statusFilter: "$statusFilter", maxRows: 50 })
  wiredWells({ error, data }) {
    if (data) {
      this.wells = data.map((row) => ({
        ...row,
        Account__r: row.Account__r?.Name || "",
        Lease__r: row.Lease__r?.Name || ""
      }));
      this.hasError = false;
    } else if (error) {
      this.hasError = true;
      this.errorMessage = error.body?.message || "Failed to load wells.";
    }
  }

  @wire(getWellStatusCounts)
  wiredCounts({ error, data }) {
    if (data) {
      this.statusCounts = data;
    }
  }

  @wire(getWellProduction, { wellId: "$selectedWellId", monthsBack: 12 })
  wiredProduction({ error, data }) {
    if (data) {
      this.productionData = data;
    }
  }

  @wire(getWellTelemetry, { wellId: "$selectedWellId", hoursBack: 24 })
  wiredTelemetry({ error, data }) {
    if (data) {
      this.telemetryData = data.map((row) => {
        let primaryLabel = "";
        if (row.Measurement_Type__c === "Pressure") {
          primaryLabel = `${row.Pressure__c ?? ""} psi`;
        } else if (row.Measurement_Type__c === "Temperature") {
          primaryLabel = `${row.Temperature__c ?? ""} °F`;
        } else {
          primaryLabel = `${row.Gross_Volume__c ?? ""} ${row.Measurement_Type__c === "Gas Flow" ? "MCF" : "bbls"}`;
        }
        return {
          ...row,
          readingLabel: new Date(row.Reading_DateTime__c).toLocaleString(),
          primaryLabel
        };
      });
      this.hasError = false;
    } else if (error) {
      this.telemetryData = [];
    }
  }

  get hasWells() {
    return this.wells.length > 0;
  }

  get hasProduction() {
    return this.productionData.length > 0;
  }

  get hasTelemetry() {
    return this.telemetryData.length > 0;
  }

  get totalWells() {
    return this.statusCounts.total || 0;
  }

  handleWellSelect(event) {
    const row = event.detail.selectedRows;
    if (row && row.length > 0) {
      this.selectedWellId = row[0].Id;
    }
  }

  handleStatusFilterChange(event) {
    this.statusFilter = event.target.value;
  }
}
