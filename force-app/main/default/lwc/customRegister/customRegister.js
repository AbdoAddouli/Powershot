import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { isRequired, isValidEmail, isValidPhone } from "c/psAuthLib";
import submitRequest from "@salesforce/apex/AccessRequestService.submitRequest";
import isAuthenticated from "@salesforce/apex/PowerShotLoginController.isAuthenticated";

const EMPTY_FORM = {
  firstName: "",
  lastName: "",
  email: "",
  company: "",
  phone: "",
  jobTitle: ""
};

export default class CustomRegister extends NavigationMixin(LightningElement) {
  @api loginPageName = "Login";
  @api successPageName = "Login";
  @api homePageName = "Home";

  checking = true;

  connectedCallback() {
    isAuthenticated()
      .then((auth) => {
        if (auth) {
          this.navigateTo(this.homePageName);
          return;
        }
        this.checking = false;
      })
      .catch(() => {
        this.checking = false;
      });
  }

  form = { ...EMPTY_FORM };
  errors = {};
  agreed = false;
  loading = false;
  serverError = "";

  get firstNameClass() {
    return "ps-input" + (this.errors.firstName ? " ps-input-error" : "");
  }
  get firstNameInvalid() {
    return this.errors.firstName ? "true" : "false";
  }
  get lastNameClass() {
    return "ps-input" + (this.errors.lastName ? " ps-input-error" : "");
  }
  get lastNameInvalid() {
    return this.errors.lastName ? "true" : "false";
  }
  get emailClass() {
    return "ps-input pl-10" + (this.errors.email ? " ps-input-error" : "");
  }
  get emailInvalid() {
    return this.errors.email ? "true" : "false";
  }
  get companyClass() {
    return "ps-input pl-10" + (this.errors.company ? " ps-input-error" : "");
  }
  get companyInvalid() {
    return this.errors.company ? "true" : "false";
  }
  get phoneClass() {
    return "ps-input pl-10" + (this.errors.phone ? " ps-input-error" : "");
  }
  get phoneInvalid() {
    return this.errors.phone ? "true" : "false";
  }
  get jobTitleClass() {
    return "ps-input pl-10" + (this.errors.jobTitle ? " ps-input-error" : "");
  }
  get jobTitleInvalid() {
    return this.errors.jobTitle ? "true" : "false";
  }
  get agreedInvalid() {
    return this.errors.agreed ? "true" : "false";
  }

  handleInput(e) {
    const field = e.currentTarget.dataset.field;
    if (!field || !(field in EMPTY_FORM)) return;
    this.form = { ...this.form, [field]: e.target.value };
    this.errors = { ...this.errors, [field]: undefined };
  }

  handleAgreed(e) {
    this.agreed = e.target.checked;
    this.errors = { ...this.errors, agreed: undefined };
  }

  validate() {
    const errors = {};
    const { firstName, lastName, email, company, phone } = this.form;

    if (!isRequired(firstName)) {
      errors.firstName = "First name is required.";
    }
    if (!isRequired(lastName)) {
      errors.lastName = "Last name is required.";
    }
    if (!isRequired(email)) {
      errors.email = "Work email is required.";
    } else if (!isValidEmail(email)) {
      errors.email = "Enter a valid work email address.";
    }
    if (!isRequired(company)) {
      errors.company = "Company / Account name is required.";
    }
    if (!isValidPhone(phone)) {
      errors.phone = "Enter a valid phone number.";
    }
    if (!this.agreed) {
      errors.agreed =
        "You must agree to the Partner Terms and Data Processing Policy.";
    }

    return errors;
  }

  async handleSubmit(e) {
    e.preventDefault();
    this.serverError = "";

    const errors = this.validate();
    this.errors = errors;

    const firstErrorKey = Object.keys(errors)[0];
    if (firstErrorKey) {
      const el = this.template.querySelector(`[data-field="${firstErrorKey}"]`);
      if (el && typeof el.focus === "function") el.focus();
      return;
    }

    this.loading = true;
    try {
      const result = await submitRequest({
        firstName: this.form.firstName,
        lastName: this.form.lastName,
        email: this.form.email,
        company: this.form.company,
        requestedProfile: null,
        comments: this.form.jobTitle
      });

      this.loading = false;
      if (result && result.success) {
        this.navigateTo(this.successPageName);
      } else {
        this.serverError =
          (result && result.message) ||
          "We couldn't submit your request. Please try again.";
      }
    } catch {
      this.loading = false;
      this.serverError =
        "Something went wrong submitting your request. Please try again.";
    }
  }

  goBack(e) {
    if (e.type === "keydown" && e.key !== "Enter" && e.key !== " ") return;
    e.preventDefault();
    this.navigateTo(this.loginPageName);
  }

  navigateTo(pageName) {
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: { name: pageName }
    });
  }
}