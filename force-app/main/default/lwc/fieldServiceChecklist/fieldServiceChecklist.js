import { LightningElement, api, wire } from 'lwc';
import getChecklistItems from '@salesforce/apex/InspectionService.getChecklistItems';
import submitChecklist from '@salesforce/apex/InspectionService.submitChecklist';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class FieldServiceChecklist extends LightningElement {
    @api recordId;
    @api checklistType = 'Inspection';

    checklistItems = [];
    error;
    wiredResult;
    isSubmitting = false;
    overallStatus = 'pending';

    @wire(getChecklistItems, { parentId: '$recordId', type: '$checklistType' })
    wiredChecklist(result) {
        this.wiredResult = result;
        const { error, data } = result;
        if (data) {
            this.checklistItems = data.map(item => ({
                ...item,
                checked: false,
                id: item.Id || this.generateId()
            }));
            this.error = undefined;
        } else if (error) {
            this.checklistItems = [];
            this.error = error;
        }
    }

    generateId() {
        return 'item_' + Math.random().toString(36).substr(2, 9);
    }

    handleCheckboxChange(event) {
        const itemId = event.target.dataset.id;
        const checked = event.target.checked;
        this.checklistItems = this.checklistItems.map(item =>
            item.id === itemId ? { ...item, checked } : item
        );
        this.updateOverallStatus();
    }

    updateOverallStatus() {
        const total = this.checklistItems.length;
        const completed = this.checklistItems.filter(i => i.checked).length;
        if (completed === 0) this.overallStatus = 'pending';
        else if (completed < total) this.overallStatus = 'partial';
        else this.overallStatus = 'complete';
    }

    handleCommentChange(event) {
        const itemId = event.target.dataset.id;
        const comment = event.target.value;
        this.checklistItems = this.checklistItems.map(item =>
            item.id === itemId ? { ...item, Comment__c: comment } : item
        );
    }

    handlePhotoUpload(event) {
        const itemId = event.target.dataset.id;
        const files = event.target.files;
        if (files && files.length > 0) {
            this.checklistItems = this.checklistItems.map(item =>
                item.id === itemId ? { ...item, PhotoUploaded: true, PhotoName: files[0].name } : item
            );
        }
    }

    async handleSubmit() {
        this.isSubmitting = true;
        try {
            const results = this.checklistItems.map(item => ({
                Id: item.Id || null,
                Status__c: item.checked ? 'Completed' : 'Pending',
                Comment__c: item.Comment__c || ''
            }));

            await submitChecklist({ checklistData: JSON.stringify(results), parentId: this.recordId });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Checklist Submitted',
                message: `${this.checklistItems.filter(i => i.checked).length} of ${this.checklistItems.length} items completed`,
                variant: 'success'
            }));
            await refreshApex(this.wiredResult);
        } catch (err) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error submitting checklist',
                message: err.body?.message,
                variant: 'error'
            }));
        } finally {
            this.isSubmitting = false;
        }
    }

    get progressPercent() {
        if (!this.checklistItems.length) return 0;
        return Math.round((this.checklistItems.filter(i => i.checked).length / this.checklistItems.length) * 100);
    }

    get completedCount() {
        return this.checklistItems.filter(i => i.checked).length;
    }

    get totalCount() {
        return this.checklistItems.length;
    }

    get hasItems() {
        return this.checklistItems && this.checklistItems.length > 0;
    }

    get hasError() {
        return this.error != null;
    }

    get canSubmit() {
        return this.hasItems && !this.isSubmitting;
    }

    get submitLabel() {
        return this.isSubmitting ? 'Submitting...' : 'Submit Checklist';
    }

    get isComplete() {
        return this.overallStatus === 'complete';
    }
}
