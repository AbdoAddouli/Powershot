import { LightningElement, api, wire } from 'lwc';
import getWellProduction from '@salesforce/apex/WellStatusService.getWellProduction';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    { label: 'Date', fieldName: 'Production_Date__c', type: 'date' },
    { label: 'Oil (bbls)', fieldName: 'Oil_Volume__c', type: 'number', cellAttributes: { class: 'slds-text-color_success' } },
    { label: 'Gas (MCF)', fieldName: 'Gas_Volume__c', type: 'number', cellAttributes: { class: 'slds-text-color_weak' } },
    { label: 'Water (bbls)', fieldName: 'Water_Volume__c', type: 'number', cellAttributes: { class: 'slds-text-color_inverse-weak' } }
];

export default class WellProductionChart extends LightningElement {
    @api recordId;
    data = [];
    error;
    columns = COLUMNS;
    chartData = [];
    productionStats = { oilTotal: 0, gasTotal: 0, waterTotal: 0, daysOn: 0 };

    @wire(getWellProduction, { wellId: '$recordId' })
    wiredProduction({ error, data }) {
        if (data) {
            this.data = data;
            this.error = undefined;
            this.buildChartData(data);
            this.calculateStats(data);
        } else if (error) {
            this.data = [];
            this.error = error;
            this.dispatchEvent(
                new ShowToastEvent({ title: 'Error loading production', message: error.body?.message, variant: 'error' })
            );
        }
    }

    buildChartData(records) {
        this.chartData = records.map(r => ({
            date: r.Production_Date__c,
            oil: r.Oil_Volume__c ?? 0,
            gas: r.Gas_Volume__c ?? 0,
            water: r.Water_Volume__c ?? 0
        }));
    }

    calculateStats(records) {
        const stats = { oilTotal: 0, gasTotal: 0, waterTotal: 0, daysOn: 0 };
        records.forEach(r => {
            stats.oilTotal += r.Oil_Volume__c ?? 0;
            stats.gasTotal += r.Gas_Volume__c ?? 0;
            stats.waterTotal += r.Water_Volume__c ?? 0;
            stats.daysOn += r.Days_On_Production__c ?? 0;
        });
        this.productionStats = stats;
    }

    get hasData() {
        return this.data && this.data.length > 0;
    }

    get hasError() {
        return this.error != null;
    }
}
