import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import forgotPassword from "@salesforce/apex/PowerShotForgotPasswordController.forgotPassword";

export default class CustomCheckEmail extends NavigationMixin(
  LightningElement
) {
  @api loginPageName = "Login";
  @api forgotPageName = "Forgot_Password";

  resending = false;
  error = "";
  email = "";

  connectedCallback() {
    // L'email est passé via l'état de navigation (comm__namedPage state) →
    // paramètre de requête "c__email" (préfixé dans LWR).
    const params = new URLSearchParams(window.location.search);
    this.email = params.get("c__email") || params.get("email") || "";
  }

  get canResend() {
    return Boolean(this.email);
  }

  async resend() {
    this.resending = true;
    this.error = "";
    try {
      await forgotPassword({ email: this.email });
      this.resending = false;
    } catch {
      this.resending = false;
      this.error = "We couldn't resend the email. Please try again.";
    }
  }

  goBack() {
    this.navigateTo(this.loginPageName);
  }
  get isDisableResend() {
    return this.resending || !this.canResend;
  }
  navigateTo(pageName) {
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: { name: pageName }
    });
  }
}