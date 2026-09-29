import { LightningElement } from 'lwc';
import provisionStore from '@salesforce/apex/ProvisioningService.provisionStore';

export default class StoreProvisioning extends LightningElement {
    storeName = '';
    storeType = '';
    websiteUrl = '';

    isProvisioning = false;

    typeOptions = [
        { label: 'TikTok', value: 'TikTok' },
        { label: 'Snapchat', value: 'Snap' },
        { label: 'Meta', value: 'Meta' },
        { label: 'Shopify', value: 'Shopify' },
        { label: 'LinkedIn', value: 'LinkedIn' },
        { label: 'Other', value: 'Other' }
    ];

    handleNameChange(event) {
        this.storeName = event.target.value;
    }

    handleTypeChange(event) {
        this.storeType = event.detail.value;
    }

    handleUrlChange(event) {
        this.websiteUrl = event.target.value;
    }

    handleProvision() {
        if (!this.storeName || !this.storeType || !this.websiteUrl) {
            this.showToast('Error', 'Please fill in all required fields.', 'error');
            return;
        }

        this.isProvisioning = true;

        provisionStore({
            name: this.storeName,
            storeType: this.storeType,
            websiteUrl: this.websiteUrl
        })
        .then(() => {
            this.isProvisioning = false;
            this.showToast('Success', 'Store provisioning started. Check the Store Manager for status.', 'success');
            this.dispatchEvent(new CustomEvent('gotostores', { bubbles: true, composed: true }));
        })
        .catch(error => {
            this.isProvisioning = false;
            const msg = error.body?.message || error.message || 'An unexpected error occurred.';
            this.showToast('Error', msg, 'error');
        });
    }

    handleCancelForm() {
        this.dispatchEvent(new CustomEvent('gotostores', { bubbles: true, composed: true }));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new CustomEvent('showtoast', {
                bubbles: true,
                composed: true,
                detail: { title, message, variant }
            })
        );
    }
}