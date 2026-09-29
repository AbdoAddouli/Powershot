import { LightningElement, wire, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";
import getProfile from "@salesforce/apex/PowerShotProfileController.getProfile";
import updateContact from "@salesforce/apex/PowerShotProfileController.updateContact";
import { isValidEmail } from "c/psAuthLib";

const EDITABLE_FIELDS = [
  "firstName",
  "lastName",
  "title",
  "email",
  "phone",
  "mobilePhone",
  "mailingStreet",
  "mailingCity",
  "mailingState",
  "mailingPostalCode",
  "mailingCountry"
];

export default class PortalProfile extends NavigationMixin(LightningElement) {
  @api profileTitle = "My Profile";
  @api forgotPageName = "Forgot_Password";

  profile = null;
  form = {};
  error = "";
  loadError = "";
  savedMessage = "";
  saving = false;

  _wiredResult;

  @wire(getProfile)
  wiredProfile(result) {
    this._wiredResult = result;
    if (result.data) {
      this.profile = result.data;
      this.form = this.copyEditable(result.data);
      this.error = "";
      this.loadError = "";
    } else if (result.error) {
      this.profile = null;
      this.loadError =
        (result.error.body && result.error.body.message) ||
        JSON.stringify(result.error) ||
        "Failed to load profile.";
    }
  }

  get loading() {
    return this.profile === null && this.loadError === "";
  }

  get ready() {
    return this.profile !== null;
  }

  async retryProfile() {
    this.loadError = "";
    if (this._wiredResult) {
      await refreshApex(this._wiredResult);
    }
  }

  get initial() {
    const name = (this.displayName || "").trim();
    return name ? name.charAt(0).toUpperCase() : "?";
  }

  get displayName() {
    const first = (this.profile && this.profile.firstName) || "";
    const last = (this.profile && this.profile.lastName) || "";
    const name = [first, last].join(" ").trim();
    return name || this.profile?.userEmail || "Partner";
  }

  get title() {
    return (this.profile && this.profile.title) || "";
  }

  get companyName() {
    return (this.profile && this.profile.accountName) || "";
  }

  get username() {
    return (this.profile && this.profile.username) || "";
  }

  get lastLoginLabel() {
    const date = this.profile && this.profile.lastLoginDate;
    return date ? new Date(date).toLocaleString() : "—";
  }

  get companyPhone() {
    return (this.profile && this.profile.accountPhone) || "";
  }

  get companyAddress() {
    const p = this.profile;
    if (!p) return "";
    return [
      p.billingStreet,
      p.billingCity,
      p.billingState,
      p.billingPostalCode,
      p.billingCountry
    ]
      .filter((part) => part && String(part).trim())
      .join(", ");
  }

  get dirty() {
    if (!this.profile) return false;
    return EDITABLE_FIELDS.some((field) => {
      const a = this.profile[field];
      const b = this.form[field];
      return (a || "").trim() !== (b || "").trim();
    });
  }

  copyEditable(data) {
    const copy = {};
    EDITABLE_FIELDS.forEach((field) => {
      copy[field] = data[field] || "";
    });
    return copy;
  }

  handleInput(event) {
    const field = event.currentTarget.dataset.field;
    if (!field || !EDITABLE_FIELDS.includes(field)) return;
    this.form[field] = event.target.value;
    this.error = "";
    this.savedMessage = "";
  }

  async saveChanges(event) {
    if (event && typeof event.preventDefault === "function") {
      event.preventDefault();
    }
    this.error = "";
    this.savedMessage = "";

    const first = (this.form.firstName || "").trim();
    const last = (this.form.lastName || "").trim();
    const email = (this.form.email || "").trim();

    if (!first || !last) {
      this.error = "First and last name are required.";
      return;
    }
    if (email && !isValidEmail(email)) {
      this.error = "Enter a valid email address.";
      return;
    }

    this.saving = true;
    try {
      const result = await updateContact({
        fields: {
          FirstName: first,
          LastName: last,
          Title: this.form.title,
          Email: email,
          Phone: this.form.phone,
          MobilePhone: this.form.mobilePhone,
          MailingStreet: this.form.mailingStreet,
          MailingCity: this.form.mailingCity,
          MailingState: this.form.mailingState,
          MailingPostalCode: this.form.mailingPostalCode,
          MailingCountry: this.form.mailingCountry
        }
      });
      this.saving = false;

      if (result && result.success) {
        this.savedMessage = result.message || "Profile updated successfully.";
        await refreshApex(this._wiredResult);
      } else {
        this.error =
          (result && result.message) || "Update failed. Please try again.";
      }
    } catch {
      this.saving = false;
      this.error = "Update failed. Please try again.";
    }
  }

  cancelChanges() {
    if (this.saving) return;
    if (this.profile) {
      this.form = this.copyEditable(this.profile);
    }
    this.error = "";
    this.savedMessage = "";
  }

  goForgot() {
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: { name: this.forgotPageName }
    });
  }
}
