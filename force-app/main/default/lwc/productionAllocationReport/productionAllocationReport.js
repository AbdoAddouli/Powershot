import { LightningElement, api, wire } from 'lwc';
import getProductionHistory from '@salesforce/apex/ProductionAllocationService.getProductionHistory';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    { label: 'Period Start', fieldName: 'Period_Start__c', type: 'date' },
    { label: 'Period End', fieldName: 'Period_End__c', type: 'date' },
    { label: 'Oil (bbls)', fieldName: 'Oil_Volume_bbls__c', type: 'number', cellAttributes: { alignment: 'left' } },
    { label: 'Gas (MCF)', fieldName: 'Gas_Volume_MCF__c', type: 'number', cellAttributes: { alignment: 'left' } },
    { label: 'Revenue', fieldName: 'Allocated_Revenue__c', type: 'currency', cellAttributes: { alignment: 'left' } },
    { label: 'WI %', fieldName: 'Working_Interest_Share__c', type: 'number', cellAttributes: { alignment: 'left' } },
    { label: 'NRI %', fieldName: 'Net_Revenue_Interest_Share__c', type: 'number', cellAttributes: { alignment: 'left' } }
];

export default class ProductionAllocationReport extends LightningElement {
    @api recordId;
    @api monthsBack = 12;

    allocations = [];
    error;
    columns = COLUMNS;
    summary = { totalVolume: 0, totalRevenue: 0, ownerCount: 0 };

    @wire(getProductionHistory, { wellId: '$recordId', months: '$monthsBack' })
    wiredAllocations({ error, data }) {
        if (data) {
            this.allocations = data;
            this.error = undefined;
            this.calculateSummary();
        } else if (error) {
            this.allocations = [];
            this.error = error;
            this.dispatchEvent(
                new ShowToastEvent({ title: 'Error loading allocations', message: error.body?.message, variant: 'error' })
            );
        }
    }

    calculateSummary() {
        let totalOil = 0;
        let totalGas = 0;
        let totalRevenue = 0;

        this.allocations.forEach(a => {
            totalOil += a.Oil_Volume_bbls__c ?? 0;
            totalGas += a.Gas_Volume_MCF__c ?? 0;
            totalRevenue += a.Allocated_Revenue__c ?? 0;
        });

        this.summary = {
            totalOil,
            totalGas,
            totalRevenue
        };
    }

    handleMonthsChange(event) {
        this.monthsBack = parseInt(event.detail.value, 10);
    }

    get hasData() {
        return this.allocations && this.allocations.length > 0;
    }

    get hasError() {
        return this.error != null;
    }

    get monthOptions() {
        return [
            { label: '3 months', value: '3' },
            { label: '6 months', value: '6' },
            { label: '12 months', value: '12' },
            { label: '24 months', value: '24' }
        ];
    }
}
