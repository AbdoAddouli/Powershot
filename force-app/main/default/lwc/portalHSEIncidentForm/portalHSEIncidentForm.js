import { LightningElement, wire, api } from "lwc";
import getIncidents from "@salesforce/apex/PortalIncidentController.getIncidents";
import createIncident from "@salesforce/apex/PortalIncidentController.createIncident";
import getIncidentDetail from "@salesforce/apex/PortalIncidentController.getIncidentDetail";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

const INCIDENT_COLUMNS = [
  { label: "Incident", fieldName: "Name", type: "text" },
  { label: "Type", fieldName: "Incident_Type__c", type: "text" },
  { label: "Date", fieldName: "Incident_Date__c", type: "date" },
  { label: "Severity", fieldName: "Severity__c", type: "text" },
  { label: "Status", fieldName: "Status__c", type: "text" },
  { label: "Location", fieldName: "Location__c", type: "text" },
  { label: "Well", fieldName: "Well__r", type: "text" }
];

export default class PortalHSEIncidentForm extends LightningElement {
  @api severityFilter = "";

  incidents = [];
  columns = INCIDENT_COLUMNS;
  selectedIncidentId = null;
  incidentDetail = null;
  showForm = false;
  hasError = false;
  errorMessage = "";

  incidentType = "";
  incidentDate = "";
  severity = "";
  location = "";
  description = "";
  spillVolume = null;

  @wire(getIncidents, { severityFilter: "$severityFilter", maxRows: 50 })
  wiredIncidents({ error, data }) {
    if (data) {
      this.incidents = data.map((row) => ({
        ...row,
        Well__r: row.Well__r?.Name || ""
      }));
      this.hasError = false;
    } else if (error) {
      this.hasError = true;
      this.errorMessage = error.body?.message || "Failed to load incidents.";
    }
  }

  get hasIncidents() {
    return this.incidents.length > 0;
  }

  get highOpen() {
    return this.incidents.filter(
      (i) =>
        (i.Severity__c === "Critical" || i.Severity__c === "High") &&
        i.Status__c !== "Closed"
    ).length;
  }

  get mediumOpen() {
    return this.incidents.filter(
      (i) => i.Severity__c === "Medium" && i.Status__c !== "Closed"
    ).length;
  }

  get lowOpen() {
    return this.incidents.filter(
      (i) => i.Severity__c === "Low" && i.Status__c !== "Closed"
    ).length;
  }

  get closedCount() {
    return this.incidents.filter((i) => i.Status__c === "Closed").length;
  }

  get incidentTypeOptions() {
    return [
      { label: "Spill", value: "Spill" },
      { label: "Fire/Explosion", value: "Fire/Explosion" },
      { label: "Injury", value: "Injury" },
      { label: "Equipment Failure", value: "Equipment Failure" },
      { label: "Environmental", value: "Environmental" },
      { label: "Near Miss", value: "Near Miss" },
      { label: "Other", value: "Other" }
    ];
  }

  get severityOptions() {
    return [
      { label: "Critical", value: "Critical" },
      { label: "High", value: "High" },
      { label: "Medium", value: "Medium" },
      { label: "Low", value: "Low" }
    ];
  }

  handleRowSelect(event) {
    const selected = event.detail.selectedRows;
    if (selected && selected.length > 0) {
      this.selectedIncidentId = selected[0].Id;
      this.loadDetail(selected[0].Id);
    }
  }

  async loadDetail(id) {
    try {
      this.incidentDetail = await getIncidentDetail({ incidentId: id });
    } catch (e) {
      this.incidentDetail = null;
    }
  }

  handleNewIncident() {
    this.showForm = true;
    this.incidentDetail = null;
    this.incidentType = "";
    this.incidentDate = "";
    this.severity = "";
    this.location = "";
    this.description = "";
    this.spillVolume = null;
  }

  handleCancel() {
    this.showForm = false;
  }

  handleTypeChange(event) {
    this.incidentType = event.target.value;
  }

  handleDateChange(event) {
    this.incidentDate = event.target.value;
  }

  handleSeverityChange(event) {
    this.severity = event.target.value;
  }

  handleLocationChange(event) {
    this.location = event.target.value;
  }

  handleDescriptionChange(event) {
    this.description = event.target.value;
  }

  handleSpillVolumeChange(event) {
    this.spillVolume = event.target.value ? Number(event.target.value) : null;
  }

  async handleSubmit() {
    if (!this.incidentType || !this.severity) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Validation Error",
          message: "Incident Type and Severity are required.",
          variant: "error"
        })
      );
      return;
    }

    const incident = {
      Incident_Type__c: this.incidentType,
      Severity__c: this.severity,
      Location__c: this.location,
      Description__c: this.description,
      Spill_Volume__c: this.spillVolume
    };

    if (this.incidentDate) {
      incident.Incident_Date__c = this.incidentDate;
    }

    try {
      await createIncident({ incident });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "Incident created successfully.",
          variant: "success"
        })
      );
      this.showForm = false;
    } catch (e) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: e.body?.message || "Failed to create incident.",
          variant: "error"
        })
      );
    }
  }
}
