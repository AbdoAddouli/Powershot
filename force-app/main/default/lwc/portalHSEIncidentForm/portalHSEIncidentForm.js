import { LightningElement, wire, api } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getIncidents from "@salesforce/apex/PortalIncidentController.getIncidents";
import createIncident from "@salesforce/apex/PortalIncidentController.createIncident";
import getIncidentDetail from "@salesforce/apex/PortalIncidentController.getIncidentDetail";
import getIncidentStats from "@salesforce/apex/PortalIncidentController.getIncidentStats";
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

const INCIDENT_TYPE_OPTIONS = [
  { label: "Spill", value: "Spill" },
  { label: "Fire/Explosion", value: "Fire/Explosion" },
  { label: "Injury", value: "Injury" },
  { label: "Equipment Failure", value: "Equipment Failure" },
  { label: "Environmental", value: "Environmental" },
  { label: "Near Miss", value: "Near Miss" },
  { label: "Other", value: "Other" }
];

const SEVERITY_OPTIONS = [
  { label: "Critical", value: "Critical" },
  { label: "High", value: "High" },
  { label: "Medium", value: "Medium" },
  { label: "Low", value: "Low" }
];

export default class PortalHSEIncidentForm extends LightningElement {
  @api severityFilter = "";

  incidents = [];
  columns = INCIDENT_COLUMNS;
  wiredResult = null;
  statsResult = null;
  stats = { highOpen: 0, mediumOpen: 0, lowOpen: 0, closedCount: 0 };
  selectedIncidentId = null;
  incidentDetail = null;
  showForm = false;
  isSubmitting = false;
  hasError = false;
  errorMessage = "";

  fieldErrors = {};

  incidentType = "";
  incidentDate = "";
  severity = "";
  location = "";
  description = "";
  spillVolume = null;

  @wire(getIncidentStats)
  wiredStats(result) {
    this.statsResult = result;
    const { error, data } = result;
    if (data) {
      this.stats = {
        highOpen: data.highOpen || 0,
        mediumOpen: data.mediumOpen || 0,
        lowOpen: data.lowOpen || 0,
        closedCount: data.closedCount || 0
      };
    }
  }

  @wire(getIncidents, { severityFilter: "$severityFilter", maxRows: 50 })
  wiredIncidents(result) {
    this.wiredResult = result;
    const { error, data } = result;
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
    return this.stats.highOpen;
  }

  get mediumOpen() {
    return this.stats.mediumOpen;
  }

  get lowOpen() {
    return this.stats.lowOpen;
  }

  get closedCount() {
    return this.stats.closedCount;
  }

  get incidentTypeOptions() {
    return INCIDENT_TYPE_OPTIONS;
  }

  get severityOptions() {
    return SEVERITY_OPTIONS;
  }

  get submitLabel() {
    return this.isSubmitting ? "Submitting…" : "Submit";
  }

  get incidentTypeError() {
    return this.fieldErrors.incidentType;
  }

  get severityError() {
    return this.fieldErrors.severity;
  }

  get descriptionError() {
    return this.fieldErrors.description;
  }

  get spillVolumeError() {
    return this.fieldErrors.spillVolume;
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
    } catch {
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

  handleFieldChange(event) {
    const field = event.target.dataset.field;
    const value = event.target.value;
    this[field] = field === "spillVolume" ? (value === "" ? null : Number(value)) : value;
    if (this.fieldErrors[field]) {
      this.fieldErrors = { ...this.fieldErrors, [field]: undefined };
    }
  }

  validate() {
    const errors = {};
    if (!this.incidentType) errors.incidentType = "Incident Type is required.";
    if (!this.severity) errors.severity = "Severity is required.";
    if (!this.description || !this.description.trim())
      errors.description = "Description is required.";
    if (this.spillVolume === null || this.spillVolume === undefined || isNaN(this.spillVolume))
      errors.spillVolume = "Spill Volume is required.";
    this.fieldErrors = errors;
    return Object.values(errors).every((e) => e === undefined) && Object.keys(errors).length === 0;
  }

  async handleSubmit() {
    if (!this.validate()) {
      this.notify(
        "Validation Error",
        "Please complete the highlighted fields.",
        "error"
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

    this.isSubmitting = true;
    try {
      await createIncident({ incident });
      if (this.wiredResult) {
        await refreshApex(this.wiredResult);
      }
      if (this.statsResult) {
        await refreshApex(this.statsResult);
      }
      this.fieldErrors = {};
      this.notify("Success", "Incident created successfully.", "success");
      this.showForm = false;
    } catch (e) {
      this.notify(
        "Error",
        e.body?.message || "Failed to create incident.",
        "error"
      );
    } finally {
      this.isSubmitting = false;
    }
  }

  notify(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}