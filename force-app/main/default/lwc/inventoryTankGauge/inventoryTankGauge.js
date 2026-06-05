import { LightningElement, api, wire } from 'lwc';
import getTankInventory from '@salesforce/apex/InventoryBalanceService.getTankInventory';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class InventoryTankGauge extends LightningElement {
    @api recordId;
    @api maxTanks = 10;

    tanks = [];
    error;

    @wire(getTankInventory, { terminalId: '$recordId', limit: '$maxTanks' })
    wiredTanks({ error, data }) {
        if (data) {
            this.tanks = data.map(t => this.enrichTank(t));
            this.error = undefined;
        } else if (error) {
            this.tanks = [];
            this.error = error;
            this.dispatchEvent(
                new ShowToastEvent({ title: 'Error loading tanks', message: error.body?.message, variant: 'error' })
            );
        }
    }

    enrichTank(tank) {
        const capacity = tank.Tank_Capacity__c || 1;
        const currentVolume = tank.Current_Volume__c || 0;
        const fillPct = Math.min(100, Math.round((currentVolume / capacity) * 100));
        let gaugeClass = 'slds-text-color_success';
        let levelClass = 'gauge-fill-low';
        if (fillPct >= 85) {
            gaugeClass = 'slds-text-color_error';
            levelClass = 'gauge-fill-high';
        } else if (fillPct >= 60) {
            gaugeClass = 'slds-text-color_warning';
            levelClass = 'gauge-fill-mid';
        }

        return {
            ...tank,
            fillPct,
            gaugeClass,
            levelClass,
            capacityFormatted: this.formatNumber(capacity),
            volumeFormatted: this.formatNumber(currentVolume),
            availableFormatted: this.formatNumber(tank.Available_Volume__c || 0)
        };
    }

    formatNumber(val) {
        if (val == null) return '0';
        return Number(val).toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
    }

    get gaugeStyle() {
        return `width: ${this.fillPct}%`;
    }

    get hasTanks() {
        return this.tanks && this.tanks.length > 0;
    }

    get hasError() {
        return this.error != null;
    }
}
