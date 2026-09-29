import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import isCurrentUserAdmin from '@salesforce/apex/AccessRequestAdminService.isCurrentUserAdmin';
import getRequests from '@salesforce/apex/AccessRequestAdminService.getRequests';
import setStatus from '@salesforce/apex/AccessRequestAdminService.setStatus';
import deleteRequest from '@salesforce/apex/AccessRequestAdminService.deleteRequest';
import saveComment from '@salesforce/apex/AccessRequestAdminService.saveComment';

export default class CustomRequestList extends LightningElement {
  @track isLoading = true;
  @track accessDenied = false;
  @track showContent = false;
  @track requests = [];
  @track activeFilter = 'All';
  @track showDetailModal = false;
  @track selectedRequest = {};
  @track toast = { show: false, variant: 'success', message: '' };

  _wiredRequests = null;

  statusFilters = [
    { label: 'All', value: 'All', active: true, count: 0 },
    { label: 'New', value: 'New', active: false, count: 0 },
    { label: 'In Review', value: 'In Review', active: false, count: 0 },
    { label: 'Approved', value: 'Approved', active: false, count: 0 },
    { label: 'Rejected', value: 'Rejected', active: false, count: 0 },
  ];

  @wire(isCurrentUserAdmin)
  wiredAdmin({ error, data }) {
    if (data === true) {
      this.accessDenied = false;
      this.showContent = true;
    } else if (data === false) {
      this.accessDenied = true;
      this.showContent = false;
    } else if (error) {
      this.accessDenied = true;
    }
    this.isLoading = false;
  }

  @wire(getRequests)
  wiredRequests(result) {
    this._wiredRequests = result;
    const { error, data } = result;
    if (data) {
      this.requests = data.map((req) => ({
        ...req,
        formattedDate: this.formatDate(req.createdDate),
        canApprove: req.status === 'In Review',
        canReview: req.status === 'New',
        canReject: req.status === 'New' || req.status === 'In Review',
        canView: req.status === 'Approved',
      }));
      this.updateFilterCounts();
    } else if (error) {
      this.requests = [];
    }
  }

  get filteredRequests() {
    if (this.activeFilter === 'All') return this.requests;
    return this.requests.filter((r) => r.status === this.activeFilter);
  }

  get noResults() {
    return this.filteredRequests.length === 0;
  }

  get totalCount() {
    return this.requests.length;
  }

  get newCount() {
    return this.requests.filter((r) => r.status === 'New').length;
  }

  get showContent() {
    return this._showContent;
  }
  set showContent(val) {
    this._showContent = val;
  }
  _showContent = false;

  get toastClass() {
    const base = 'slds-notify slds-notify_toast';
    if (this.toast.variant === 'success') return `${base} slds-theme_success`;
    if (this.toast.variant === 'error') return `${base} slds-theme_error`;
    return `${base} slds-theme_info`;
  }

  get toastIcon() {
    return this.toast.variant === 'success' ? 'success' : this.toast.variant === 'error' ? 'error' : 'info';
  }

  updateFilterCounts() {
    this.statusFilters = this.statusFilters.map((f) => {
      let count = 0;
      if (f.value === 'All') {
        count = this.requests.length;
      } else {
        count = this.requests.filter((r) => r.status === f.value).length;
      }
      return { ...f, count };
    });
  }

  handleFilterClick(e) {
    const filterValue = e.currentTarget.dataset.filter;
    this.activeFilter = filterValue;
    this.statusFilters = this.statusFilters.map((f) => ({
      ...f,
      active: f.value === filterValue,
    }));
  }

  async handleApprove(e) {
    const requestId = e.currentTarget.dataset.id;
    await this.updateStatus(requestId, 'Approved');
  }

  async handleReview(e) {
    const requestId = e.currentTarget.dataset.id;
    await this.updateStatus(requestId, 'In Review');
  }

  async handleReject(e) {
    const requestId = e.currentTarget.dataset.id;
    await this.updateStatus(requestId, 'Rejected');
  }

  async handleApproveFromModal() {
    if (this.selectedRequest.id) {
      await this.updateStatus(this.selectedRequest.id, 'Approved');
      this.closeDetailModal();
    }
  }

  async handleRejectFromModal() {
    if (this.selectedRequest.id) {
      await this.updateStatus(this.selectedRequest.id, 'Rejected');
      this.closeDetailModal();
    }
  }

  async updateStatus(requestId, newStatus) {
    try {
      const result = await setStatus({ recordId: requestId, newStatus });
      if (result && result.success) {
        this.showToast('success', `Status updated to ${newStatus}`);
        await refreshApex(this._wiredRequests);
      } else {
        const message = (result && result.message) || 'Unable to update the status.';
        this.showToast('error', message);
      }
    } catch (error) {
      this.showToast('error', this.extractError(error));
    }
  }

  handleRowClick(e) {
    const requestId = e.currentTarget.dataset.id;
    const req = this.requests.find((r) => r.id === requestId);
    if (req) {
      this.selectedRequest = { ...req, commentDraft: req.comments || '' };
      this.showDetailModal = true;
    }
  }

  handleCommentChange(e) {
    this.selectedRequest = { ...this.selectedRequest, commentDraft: e.target.value };
  }

  async handleSaveComment() {
    if (!this.selectedRequest.id) return;
    try {
      const result = await saveComment({
        recordId: this.selectedRequest.id,
        comment: this.selectedRequest.commentDraft,
      });
      if (result && result.success) {
        this.showToast('success', 'Comment saved');
        await refreshApex(this._wiredRequests);
      } else {
        const message = (result && result.message) || 'Unable to save the comment.';
        this.showToast('error', message);
      }
    } catch (error) {
      this.showToast('error', this.extractError(error));
    }
  }

  async handleDelete(e) {
    const requestId = e.currentTarget.dataset.id;
    if (!window.confirm('Delete this request permanently?')) return;
    try {
      const result = await deleteRequest({ recordId: requestId });
      if (result && result.success) {
        this.showToast('success', 'Request deleted');
        await refreshApex(this._wiredRequests);
      } else {
        const message = (result && result.message) || 'Unable to delete the request.';
        this.showToast('error', message);
      }
    } catch (error) {
      this.showToast('error', this.extractError(error));
    }
  }

  closeDetailModal() {
    this.showDetailModal = false;
    this.selectedRequest = {};
  }

  getStatusClass(status) {
    const base = 'slds-badge status-badge';
    if (status === 'Approved') return `${base} status-approved`;
    if (status === 'New') return `${base} status-new`;
    if (status === 'In Review') return `${base} status-review`;
    if (status === 'Rejected') return `${base} status-rejected`;
    return base;
  }

  formatDate(dateStr) {
    if (!dateStr) return '';
    const d = new Date(dateStr);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return `${months[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()} ${d.getHours()}:${String(d.getMinutes()).padStart(2, '0')}`;
  }

  showToast(variant, message) {
    this.toast = {
      show: true,
      variant,
      message,
      isSuccess: variant === 'success',
      isError: variant === 'error',
    };
    setTimeout(() => {
      this.toast = { ...this.toast, show: false };
    }, 3500);
  }

  extractError(error) {
    if (error && error.body && error.body.message) return error.body.message;
    if (error && error.message) return error.message;
    return 'An unexpected error occurred';
  }
}