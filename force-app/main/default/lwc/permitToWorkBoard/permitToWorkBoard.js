import { LightningElement, api, wire } from 'lwc';
import getPermitsToWork from '@salesforce/apex/PermitToWorkValidationService.getPermitsToWork';
import updatePermitStatus from '@salesforce/apex/PermitToWorkValidationService.updatePermitStatus';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

const PTW_STATUSES = ['Requested', 'Issued', 'Completed', 'Cancelled'];

const COLUMNS = [
    { label: 'Permit #', fieldName: 'Name', type: 'text' },
    { label: 'Type', fieldName: 'Permit_Type__c', type: 'text' },
    { label: 'Holder', fieldName: 'Holder__c', type: 'text' },
    { label: 'Start', fieldName: 'Start_DateTime__c', type: 'datetime' },
    { label: 'End', fieldName: 'End_DateTime__c', type: 'datetime' }
];

export default class PermitToWorkBoard extends LightningElement {
    @api recordId;
    permits = [];
    error;
    wiredResult;
    columns = COLUMNS;
    statuses = PTW_STATUSES;
    selectedPermit;
    showDetailPanel = false;
    selectedStatusFilter = '';

    @wire(getPermitsToWork, { parentId: '$recordId' })
    wiredPermits(result) {
        this.wiredResult = result;
        const { error, data } = result;
        if (data) {
            this.permits = data.map(p => ({
                ...p,
                isRequested: p.Status__c === 'Requested',
                isIssued: p.Status__c === 'Issued',
                isCompleted: p.Status__c === 'Completed',
                isCancelled: p.Status__c === 'Cancelled'
            }));
            this.error = undefined;
        } else if (error) {
            this.permits = [];
            this.error = error;
        }
    }

    get requestedPermits() {
        return this.filterByStatus('Requested');
    }

    get issuedPermits() {
        return this.filterByStatus('Issued');
    }

    get completedPermits() {
        return this.filterByStatus('Completed');
    }

    get cancelledPermits() {
        return this.filterByStatus('Cancelled');
    }

    filterByStatus(status) {
        return this.permits.filter(p => p.Status__c === status);
    }

    handlePermitClick(event) {
        const permitId = event.currentTarget.dataset.id;
        this.selectedPermit = this.permits.find(p => p.Id === permitId);
        this.showDetailPanel = true;
    }

    handleCloseDetail() {
        this.showDetailPanel = false;
        this.selectedPermit = null;
    }

    async handleAdvanceStatus(event) {
        const permitId = event.currentTarget.dataset.id;
        const permit = this.permits.find(p => p.Id === permitId);
        if (!permit) return;

        const currentIdx = PTW_STATUSES.indexOf(permit.Status__c);
        if (currentIdx < 0 || currentIdx >= PTW_STATUSES.length - 1) return;

        const nextStatus = PTW_STATUSES[currentIdx + 1];
        try {
            await updatePermitStatus({ permitId, newStatus: nextStatus });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Status Updated',
                message: `Permit ${permit.Name} moved to ${nextStatus}`,
                variant: 'success'
            }));
            await refreshApex(this.wiredResult);
        } catch (err) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error updating permit',
                message: err.body?.message,
                variant: 'error'
            }));
        }
    }

    handleStatusFilterChange(event) {
        this.selectedStatusFilter = event.detail.value;
    }

    get filteredPermits() {
        if (!this.selectedStatusFilter) return this.permits;
        return this.permits.filter(p => p.Status__c === this.selectedStatusFilter);
    }

    get hasData() {
        return this.permits && this.permits.length > 0;
    }

    get hasError() {
        return this.error != null;
    }

    get cardCounts() {
        return {
            requested: this.requestedPermits.length,
            issued: this.issuedPermits.length,
            completed: this.completedPermits.length,
            cancelled: this.cancelledPermits.length
        };
    }
}
