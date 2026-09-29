import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { isValidEmail } from "c/psAuthLib";
import forgotPassword from "@salesforce/apex/PowerShotForgotPasswordController.forgotPassword";

export default class CustomForgotPassword extends NavigationMixin(
  LightningElement
) {
  @api loginPageName = "Login";
  @api checkEmailPageName = "Check_Password";

  email = "";
  error = "";
  loading = false;

  handleInput(e) {
    this.email = e.target.value;
  }

  get emailInvalid() {
    return this.error ? "true" : "false";
  }

  async handleSubmit(e) {
    e.preventDefault();
    this.error = "";

    if (!isValidEmail(this.email)) {
      this.error = "Enter a valid email address.";
      return;
    }

    this.loading = true;
    try {
      // Le résultat est toujours "générique" côté serveur : on redirige vers
      // la page Check Email même si le compte n'existe pas (anti-énumération).
      await forgotPassword({ email: this.email });
      this.loading = false;

      this[NavigationMixin.Navigate]({
        type: "comm__namedPage",
        attributes: { name: this.checkEmailPageName },
        state: { email: this.email }
      });
    } catch {
      this.loading = false;
      this.error = "We couldn't send the reset email. Please try again.";
    }
  }

  goBack() {
    this.navigateTo(this.loginPageName);
  }

  navigateTo(pageName) {
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: { name: pageName }
    });
  }
}