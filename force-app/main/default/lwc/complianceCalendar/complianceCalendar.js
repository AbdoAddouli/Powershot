import { LightningElement, api, wire } from 'lwc';
import getUpcomingDeadlines from '@salesforce/apex/ComplianceDueDateService.getUpcomingDeadlines';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    { label: 'Permit', fieldName: 'Name', type: 'text' },
    { label: 'Type', fieldName: 'Permit_Type__c', type: 'text' },
    { label: 'Agency', fieldName: 'Agency__c', type: 'text' },
    {
        label: 'Status', fieldName: 'Status__c', type: 'text',
        cellAttributes: { class: { fieldName: 'statusClass' }, iconName: { fieldName: 'statusIcon' }, iconPosition: 'left' }
    },
    { label: 'Issue Date', fieldName: 'Issue_Date__c', type: 'date' },
    { label: 'Expiration', fieldName: 'Expiration_Date__c', type: 'date', cellAttributes: { class: { fieldName: 'expirationClass' } } },
    { label: 'Days Remaining', fieldName: 'daysRemaining', type: 'number', cellAttributes: { class: { fieldName: 'daysClass' } } }
];

export default class ComplianceCalendar extends LightningElement {
    @api recordId;
    deadlines = [];
    error;
    columns = COLUMNS;
    upcoming = [];
    overdue = [];
    viewMode = 'all';

    @wire(getUpcomingDeadlines, { accountId: '$recordId' })
    wiredDeadlines({ error, data }) {
        if (data) {
            this.deadlines = data.map(p => this.enrichDeadline(p));
            this.error = undefined;
            this.categorizeDeadlines();
        } else if (error) {
            this.deadlines = [];
            this.error = error;
            this.dispatchEvent(
                new ShowToastEvent({ title: 'Error loading deadlines', message: error.body?.message, variant: 'error' })
            );
        }
    }

    enrichDeadline(permit) {
        const today = new Date();
        const expDate = permit.Expiration_Date__c ? new Date(permit.Expiration_Date__c) : null;
        const daysRemaining = expDate ? Math.ceil((expDate - today) / (1000 * 60 * 60 * 24)) : null;
        const isOverdue = daysRemaining != null && daysRemaining <= 0;

        return {
            ...permit,
            daysRemaining,
            isOverdue,
            statusClass: isOverdue ? 'slds-text-color_error' : (daysRemaining != null && daysRemaining <= 30 ? 'slds-text-color_warning' : 'slds-text-color_success'),
            statusIcon: isOverdue ? 'action:close' : (daysRemaining <= 30 ? 'action:warning' : 'action:approval'),
            expirationClass: isOverdue ? 'slds-text-color_error slds-text-font_bold' : '',
            daysClass: isOverdue ? 'slds-text-color_error' : (daysRemaining <= 30 ? 'slds-text-color_warning' : '')
        };
    }

    categorizeDeadlines() {
        this.upcoming = this.deadlines.filter(d => !d.isOverdue);
        this.overdue = this.deadlines.filter(d => d.isOverdue);
    }

    get displayDeadlines() {
        if (this.viewMode === 'upcoming') return this.upcoming;
        if (this.viewMode === 'overdue') return this.overdue;
        return this.deadlines;
    }

    handleViewModeChange(event) {
        this.viewMode = event.detail.value;
    }

    get hasData() {
        return this.deadlines && this.deadlines.length > 0;
    }

    get hasError() {
        return this.error != null;
    }

    get summary() {
        return {
            total: this.deadlines.length,
            overdue: this.overdue.length,
            upcoming: this.upcoming.length
        };
    }
}
