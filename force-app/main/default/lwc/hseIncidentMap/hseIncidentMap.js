import { LightningElement, api, wire } from 'lwc';
import getHSEIncidents from '@salesforce/apex/HSEIncidentService.getHSEIncidents';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    { label: 'Name', fieldName: 'Name', type: 'text' },
    { label: 'Type', fieldName: 'Incident_Type__c', type: 'text' },
    { label: 'Severity', fieldName: 'Severity__c', type: 'text' },
    { label: 'Status', fieldName: 'Status__c', type: 'text' },
    { label: 'Date', fieldName: 'Incident_Date__c', type: 'date' },
    { label: 'Location', fieldName: 'Location__c', type: 'text' }
];

export default class HseIncidentMap extends LightningElement {
    @api recordId;
    incidents = [];
    error;
    columns = COLUMNS;

    @wire(getHSEIncidents, { recordId: '$recordId' })
    wiredIncidents({ error, data }) {
        if (data) {
            this.incidents = data;
            this.error = undefined;
        } else if (error) {
            this.incidents = [];
            this.error = error;
            this.dispatchEvent(
                new ShowToastEvent({ title: 'Error loading incidents', message: error.body?.message, variant: 'error' })
            );
        }
    }

    get hasIncidents() {
        return this.incidents && this.incidents.length > 0;
    }

    get hasError() {
        return this.error != null;
    }
}
