import { LightningElement } from 'lwc';
import getStores from '@salesforce/apex/StoreController.getStores';
import deleteStore from '@salesforce/apex/StoreController.deleteStore';
import getStoreEvents from '@salesforce/apex/StoreController.getStoreEvents';
import getGTMConfig from '@salesforce/apex/StoreController.getGTMConfig';
import getProvisioningStatus from '@salesforce/apex/ProvisioningService.getProvisioningStatus';
import getDefaultWorkspaceId from '@salesforce/apex/GTMService.getDefaultWorkspaceId';
import getEventData from '@salesforce/apex/GAEventsController.getEventData';
import getClickEventData from '@salesforce/apex/GAEventsController.getClickEventData';

const DEFAULT_SORT = 'Name';
const DEFAULT_DIR = 'asc';
const AUTO_REFRESH_INTERVAL = 30;
const MAX_REFRESHES = 120;
const STORE_REFRESH_INTERVAL = 15000;

export default class StoreManager extends LightningElement {
    stores = [];
    events = [];
    clickEvents = [];
    isLoading = false;
    isEventsLoading = false;
    hasError = false;
    errorMessage = '';
    showModal = false;
    showProvisioning = false;
    showDetailPanel = false;
    editingStoreId = null;
    formTitle = 'New Store';
    selectedStoreName = '';
    selectedStoreId = null;
    selectedGtmUrl = '';
    selectedGa4Url = '';
    selectedGtmId = '';
    selectedGa4Id = '';
    sortedBy = DEFAULT_SORT;
    sortedDirection = DEFAULT_DIR;
    gtmAccountId = '';
    ga4AccountId = '';

    selectedDetailStoreId = '';
    activeView = 'all';
    searchTerm = '';
    eventSortBy = 'eventCount';
    eventSortDirection = 'desc';
    clickEventCount = 0;
    clickTotalUsers = 0;
    clickPercentage = 0;

    totalEventCount = 0;
    uniqueEventCount = 0;
    totalUserSum = 0;
    topEventName = '-';
    topEventCount = 0;

    autoRefresh = true;
    lastUpdated = '';
    refreshTimer;
    refreshCount = 0;

    showScriptModal = false;
    scriptStoreName = '';
    scriptData = null;
    scriptLoading = false;
    scriptError = '';
    formattedHeadSnippet = '';
    formattedBodySnippet = '';
    previewUrl = '';
    storeRefreshTimer;

    get hasStores() {
        return this.stores.length > 0;
    }

    get hasEvents() {
        return this.events.length > 0;
    }

    get hasDetailData() {
        return this.events.length > 0;
    }

    columns = [
        {
            label: 'Store Name',
            fieldName: 'Name',
            type: 'text',
            sortable: true,
            initialWidth: 200
        },
        {
            label: 'Store Type',
            fieldName: 'Store_Type__c',
            type: 'text',
            sortable: true,
            initialWidth: 120
        },
        {
            label: 'Website URL',
            fieldName: 'Website_URL__c',
            type: 'url',
            sortable: true,
            initialWidth: 300
        },
        {
            label: 'Status',
            fieldName: 'Provisioning_Status__c',
            type: 'text',
            sortable: true,
            initialWidth: 100
        },
        {
            label: 'Active',
            fieldName: 'Active__c',
            type: 'boolean',
            sortable: true
        },
        {
            label: 'GTM',
            fieldName: 'gtmUrl',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'GTM_Container_ID__c' },
                target: '_blank',
                tooltip: 'Open GTM container'
            },
            sortable: false,
            initialWidth: 110
        },
        {
            label: 'GA4',
            fieldName: 'ga4Url',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'GA4_Property_ID__c' },
                target: '_blank',
                tooltip: 'Open GA4 property'
            },
            sortable: false,
            initialWidth: 110
        },
        {
            type: 'action',
            typeAttributes: {
                rowActions: { fieldName: 'rowActions' }
            }
        }
    ];

    eventColumns = [
        {
            label: 'Event Name',
            fieldName: 'eventName',
            type: 'text',
            sortable: true,
            initialWidth: 250
        },
        {
            label: 'Event Count',
            fieldName: 'eventCount',
            type: 'number',
            sortable: true
        },
        {
            label: 'Total Users',
            fieldName: 'totalUsers',
            type: 'number',
            sortable: true
        },
        {
            label: 'Events/User',
            fieldName: 'eventsPerUser',
            type: 'number',
            sortable: true
        }
    ];

    get detailStoreOptions() {
        const options = [{ label: 'All Stores (Global)', value: '' }];
        this.stores.forEach(s => {
            options.push({ label: s.Name, value: s.Id });
        });
        return options;
    }

    get filteredEvents() {
        let source = this.activeView === 'click' ? this.clickEvents : this.events;
        if (!this.searchTerm) return source;
        const term = this.searchTerm.toLowerCase();
        return source.filter(event =>
            event.eventName.toLowerCase().includes(term)
        );
    }

    get hasFilteredEvents() {
        return this.filteredEvents.length > 0;
    }

    connectedCallback() {
        getGTMConfig()
            .then(config => {
                this.gtmAccountId = config.gtmAccountId || '';
                this.ga4AccountId = config.ga4AccountId || '';
            })
            .catch(() => {});
        this.loadStores();
    }

    disconnectedCallback() {
        this.clearAutoRefresh();
        this.clearStoreRefresh();
    }

    buildRowActions(store) {
        const actions = [
            { label: 'View Events', name: 'view_events' }
        ];
        if (store.Provisioning_Status__c === 'Complete') {
            actions.push({ label: 'View Script', name: 'view_script' });
        }
        actions.push(
            { label: 'Edit', name: 'edit' },
            { label: 'Delete', name: 'delete' }
        );
        return actions;
    }

    loadStores() {
        this.isLoading = true;
        this.hasError = false;

        getStores()
            .then(result => {
                this.stores = result.map((store, index) => ({
                    ...store,
                    id: store.Id || index,
                    gtmUrl: this.buildGtmUrl(store),
                    ga4Url: this.buildGa4Url(store),
                    rowActions: this.buildRowActions(store)
                }));
                this.sortData(this.sortedBy, this.sortedDirection);
                this.isLoading = false;
                this.autoRefreshStoresIfPending();
            })
            .catch(error => {
                this.isLoading = false;
                this.hasError = true;
                this.errorMessage = error.body?.message || error.message || 'Failed to load stores';
            });
    }

    autoRefreshStoresIfPending() {
        this.clearStoreRefresh();
        const hasPending = this.stores.some(s => s.Provisioning_Status__c === 'Pending');
        if (hasPending) {
            this.storeRefreshTimer = setInterval(() => {
                this.loadStores();
            }, STORE_REFRESH_INTERVAL);
        }
    }

    clearStoreRefresh() {
        if (this.storeRefreshTimer) {
            clearInterval(this.storeRefreshTimer);
            this.storeRefreshTimer = null;
        }
    }

    buildGtmUrl(store) {
        if (!store.GTM_Numeric_ID__c || !this.gtmAccountId) return '';
        return 'https://tagmanager.google.com/#/container/accounts/'
            + this.gtmAccountId + '/containers/' + store.GTM_Numeric_ID__c;
    }

    buildGa4Url(store) {
        if (!store.GA4_Property_ID__c) return '';
        return 'https://analytics.google.com/analytics/web/#/p' + store.GA4_Property_ID__c + '/admin/';
    }

    handleNewStore() {
        this.showProvisioning = true;
    }

    handleGoToStores() {
        this.showProvisioning = false;
        this.showDetailPanel = false;
        this.clearAutoRefresh();
        this.loadStores();
    }

    handleSaveSuccess(event) {
        this.showModal = false;
        this.loadStores();
    }

    handleFormError(event) {
    }

    handleCancel() {
        this.showModal = false;
        this.editingStoreId = null;
    }

    handleBackdropClick() {
        this.handleCancel();
    }

    handleModalClick(event) {
        event.stopPropagation();
    }

    handleRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;

        switch (action) {
            case 'view_events':
                this.viewStoreEvents(row);
                break;
            case 'view_script':
                this.viewStoreScript(row);
                break;
            case 'edit':
                this.editStore(row);
                break;
            case 'delete':
                this.deleteStoreRecord(row);
                break;
        }
    }

    viewStoreEvents(row) {
        this.selectedStoreId = row.Id;
        this.selectedDetailStoreId = row.Id;
        this.selectedStoreName = row.Name;
        this.selectedGtmUrl = this.buildGtmUrl(row);
        this.selectedGa4Url = this.buildGa4Url(row);
        this.selectedGtmId = row.GTM_Container_ID__c || '';
        this.selectedGa4Id = row.GA4_Property_ID__c || '';
        this.showDetailPanel = true;
        this.refreshCount = 0;
        this.loadEvents();
    }

    loadEvents() {
        if (this.selectedDetailStoreId) {
            this.loadEventsForStore();
        } else {
            this.loadGlobalEvents();
        }
    }

    loadGlobalEvents() {
        this.isEventsLoading = true;

        Promise.all([getEventData(), getClickEventData()])
            .then(([eventsResult, clickResult]) => {
                if (eventsResult && eventsResult.events) {
                    this.events = eventsResult.events.map((evt, index) => ({
                        id: index,
                        eventName: evt.eventName || 'Unknown',
                        eventCount: evt.eventCount || 0,
                        totalUsers: evt.totalUsers || 0,
                        eventsPerUser: evt.totalUsers > 0
                            ? parseFloat((evt.eventCount / evt.totalUsers).toFixed(1))
                            : 0
                    }));
                } else {
                    this.events = [];
                }

                if (clickResult && clickResult.events) {
                    this.clickEvents = clickResult.events.map((evt, index) => ({
                        id: 'click-' + index,
                        eventName: evt.eventName || 'click',
                        eventCount: evt.eventCount || 0,
                        totalUsers: evt.totalUsers || 0,
                        eventsPerUser: evt.totalUsers > 0
                            ? parseFloat((evt.eventCount / evt.totalUsers).toFixed(1))
                            : 0
                    }));
                    this.clickEventCount = this.clickEvents.reduce((sum, e) => sum + e.eventCount, 0);
                    this.clickTotalUsers = this.clickEvents.reduce((sum, e) => sum + e.totalUsers, 0);
                } else {
                    this.clickEvents = [];
                    this.clickEventCount = 0;
                    this.clickTotalUsers = 0;
                }

                this.computeSummary();
                this.isEventsLoading = false;
                this.lastUpdated = new Date().toLocaleString();
                this.scheduleAutoRefresh();
            })
            .catch(error => {
                this.isEventsLoading = false;
                this.events = [];
                this.clickEvents = [];
                this.clickEventCount = 0;
                this.clickTotalUsers = 0;
                this.showToast('Error', error.body?.message || error.message || 'Failed to load events', 'error');
            });
    }

    loadEventsForStore() {
        this.isEventsLoading = true;

        getStoreEvents({ storeId: this.selectedDetailStoreId })
            .then(result => {
                if (result && result.events) {
                    this.events = result.events.map((evt, index) => ({
                        id: index,
                        eventName: evt.eventName || 'Unknown',
                        eventCount: evt.eventCount || 0,
                        totalUsers: evt.totalUsers || 0,
                        eventsPerUser: evt.totalUsers > 0
                            ? parseFloat((evt.eventCount / evt.totalUsers).toFixed(1))
                            : 0
                    }));

                    const clickEvts = result.events.filter(e => e.eventName === 'click');
                    this.clickEvents = clickEvts.map((e, i) => ({
                        id: 'click-' + i,
                        eventName: e.eventName,
                        eventCount: e.eventCount || 0,
                        totalUsers: e.totalUsers || 0,
                        eventsPerUser: e.totalUsers > 0
                            ? parseFloat((e.eventCount / e.totalUsers).toFixed(1))
                            : 0
                    }));
                    this.clickEventCount = this.clickEvents.reduce((sum, e) => sum + e.eventCount, 0);
                    this.clickTotalUsers = this.clickEvents.reduce((sum, e) => sum + e.totalUsers, 0);
                } else {
                    this.events = [];
                    this.clickEvents = [];
                    this.clickEventCount = 0;
                    this.clickTotalUsers = 0;
                }

                this.computeSummary();
                this.isEventsLoading = false;
                this.lastUpdated = new Date().toLocaleString();
                this.scheduleAutoRefresh();
            })
            .catch(error => {
                this.isEventsLoading = false;
                this.events = [];
                this.clickEvents = [];
                this.clickEventCount = 0;
                this.clickTotalUsers = 0;
                this.showToast('Error', error.body?.message || error.message || 'Failed to load events', 'error');
            });
    }

    scheduleAutoRefresh() {
        this.clearAutoRefresh();
        if (this.autoRefresh && this.showDetailPanel && this.refreshCount < MAX_REFRESHES) {
            this.refreshTimer = setInterval(() => {
                this.refreshCount++;
                this.loadEvents();
            }, AUTO_REFRESH_INTERVAL * 1000);
        }
    }

    clearAutoRefresh() {
        if (this.refreshTimer) {
            clearInterval(this.refreshTimer);
            this.refreshTimer = null;
        }
    }

    handleAutoRefreshToggle() {
        this.autoRefresh = !this.autoRefresh;
        if (this.autoRefresh) {
            this.scheduleAutoRefresh();
        } else {
            this.clearAutoRefresh();
        }
    }

    computeSummary() {
        let totalCount = 0;
        let totalUsers = 0;
        let maxCount = 0;
        let topName = '-';

        this.events.forEach(evt => {
            totalCount += evt.eventCount;
            totalUsers += evt.totalUsers;
            if (evt.eventCount > maxCount) {
                maxCount = evt.eventCount;
                topName = evt.eventName;
            }
        });

        this.totalEventCount = this.formatNumber(totalCount);
        this.uniqueEventCount = this.events.length;
        this.totalUserSum = this.formatNumber(totalUsers);
        this.topEventName = topName;
        this.topEventCount = maxCount;
        this.clickPercentage = totalCount > 0
            ? parseFloat(((this.clickEventCount / totalCount) * 100).toFixed(1))
            : 0;
    }

    formatNumber(num) {
        if (num >= 1000000) return (num / 1000000).toFixed(1) + 'M';
        if (num >= 1000) return (num / 1000).toFixed(1) + 'K';
        return num.toLocaleString();
    }

    handleRefreshEvents() {
        this.clearAutoRefresh();
        this.refreshCount = 0;
        this.loadEvents();
    }

    handleDetailStoreChange(event) {
        this.selectedDetailStoreId = event.detail.value;
        this.clearAutoRefresh();
        this.refreshCount = 0;
        if (this.selectedDetailStoreId) {
            this.selectedStoreId = this.selectedDetailStoreId;
            const store = this.stores.find(s => s.Id === this.selectedDetailStoreId);
            this.selectedStoreName = store ? store.Name : '';
            this.selectedGtmUrl = store ? this.buildGtmUrl(store) : '';
            this.selectedGa4Url = store ? this.buildGa4Url(store) : '';
            this.selectedGtmId = store ? (store.GTM_Container_ID__c || '') : '';
            this.selectedGa4Id = store ? (store.GA4_Property_ID__c || '') : '';
        } else {
            this.selectedStoreName = 'All Stores';
            this.selectedGtmUrl = '';
            this.selectedGa4Url = '';
            this.selectedGtmId = '';
            this.selectedGa4Id = '';
        }
        this.loadEvents();
    }

    handleViewChange(event) {
        this.activeView = event.target.value;
        this.searchTerm = '';
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
    }

    handleEventSort(event) {
        this.eventSortBy = event.detail.fieldName;
        this.eventSortDirection = event.detail.sortDirection;
    }

    handleCloseDetail() {
        this.showDetailPanel = false;
        this.selectedStoreId = null;
        this.selectedDetailStoreId = '';
        this.selectedStoreName = '';
        this.selectedGtmUrl = '';
        this.selectedGa4Url = '';
        this.selectedGtmId = '';
        this.selectedGa4Id = '';
        this.events = [];
        this.clickEvents = [];
        this.clickEventCount = 0;
        this.clickTotalUsers = 0;
        this.clearAutoRefresh();
    }

    viewStoreScript(row) {
        this.scriptStoreName = row.Name;
        this.showScriptModal = true;
        this.scriptLoading = true;
        this.scriptData = null;
        this.scriptError = '';

        getProvisioningStatus({ storeId: row.Id })
            .then(result => {
                this.scriptLoading = false;
                if (result && result.status === 'Complete') {
                    this.scriptData = result;
                    this.formattedHeadSnippet = this.escapeHtml(result.gtmHeadSnippet || result.gtmSnippet);
                    this.formattedBodySnippet = this.escapeHtml(result.gtmBodySnippet || '');
                    this.buildPreviewUrl(result);
                } else {
                    this.scriptError = result?.message || 'Provisioning result not available.';
                }
            })
            .catch(error => {
                this.scriptLoading = false;
                this.scriptError = error.body?.message || error.message || 'Failed to load script.';
            });
    }

    buildPreviewUrl(result) {
        if (!this.gtmAccountId || !result.gtmContainerId) {
            this.previewUrl = '';
            return;
        }
        if (result.workspaceId) {
            this.previewUrl = 'https://tagmanager.google.com/#/container/accounts/'
                + this.gtmAccountId + '/containers/'
                + result.gtmContainerId + '/workspaces/'
                + result.workspaceId;
        } else {
            getDefaultWorkspaceId({ containerId: result.gtmContainerId })
                .then(workspaceId => {
                    if (workspaceId) {
                        this.previewUrl = 'https://tagmanager.google.com/#/container/accounts/'
                            + this.gtmAccountId + '/containers/'
                            + result.gtmContainerId + '/workspaces/'
                            + workspaceId;
                    }
                })
                .catch(() => {});
        }
    }

    handleCloseScript() {
        this.showScriptModal = false;
        this.scriptData = null;
        this.scriptError = '';
        this.scriptLoading = false;
    }

    handleCopyHead() {
        const text = this.scriptData?.gtmHeadSnippet || this.scriptData?.gtmSnippet || '';
        if (!text) return;
        navigator.clipboard.writeText(text).then(() => {
            this.showToast('Success', 'Head snippet copied!', 'success');
        });
    }

    handleCopyBody() {
        const text = this.scriptData?.gtmBodySnippet || '';
        if (!text) return;
        navigator.clipboard.writeText(text).then(() => {
            this.showToast('Success', 'Body snippet copied!', 'success');
        });
    }

    escapeHtml(text) {
        if (!text) return '';
        return text
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    }

    editStore(row) {
        this.editingStoreId = row.Id;
        this.formTitle = 'Edit Store';
        this.showModal = true;
    }

    deleteStoreRecord(row) {
        if (!confirm('Delete store "' + row.Name + '"? This cannot be undone.')) return;

        deleteStore({ storeId: row.Id })
            .then(() => {
                this.loadStores();
                if (this.selectedStoreId === row.Id) {
                    this.handleCloseDetail();
                }
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || error.message, 'error');
            });
    }

    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;
        this.sortData(this.sortedBy, this.sortedDirection);
    }

    sortData(field, direction) {
        const multiplier = direction === 'asc' ? 1 : -1;
        this.stores = [...this.stores].sort((a, b) => {
            const valA = a[field] ?? '';
            const valB = b[field] ?? '';
            if (typeof valA === 'string') {
                return valA.localeCompare(valB) * multiplier;
            }
            if (typeof valA === 'boolean') {
                return ((valA === valB) ? 0 : (valA ? 1 : -1)) * multiplier;
            }
            return (valA - valB) * multiplier;
        });
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