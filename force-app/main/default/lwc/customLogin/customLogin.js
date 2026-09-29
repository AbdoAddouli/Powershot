import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import login from "@salesforce/apex/PowerShotLoginController.login";
import isAuthenticated from "@salesforce/apex/PowerShotLoginController.isAuthenticated";

export default class CustomLogin extends NavigationMixin(LightningElement) {
  @api variant = "oil";
  @api startUrl = "";
  @api homePageName = "Home";
  @api forgotPageName = "Forgot_Password";
  @api registerPageName = "Register";

  username = "";
  password = "";
  showPassword = false;
  error = "";
  loading = false;
  checking = true;

  forgotUrl = "";
  registerUrl = "";

  get passwordType() {
    return this.showPassword ? "text" : "password";
  }

  get showPasswordLabel() {
    return this.showPassword ? "Hide password" : "Show password";
  }

  get errorInvalid() {
    return this.error ? "true" : "false";
  }

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

    this.forgotRef = {
      type: "comm__namedPage",
      attributes: { name: this.forgotPageName }
    };
    this.registerRef = {
      type: "comm__namedPage",
      attributes: { name: this.registerPageName }
    };
    this[NavigationMixin.GenerateUrl](this.forgotRef).then((url) => {
      this.forgotUrl = url;
    });
    this[NavigationMixin.GenerateUrl](this.registerRef).then((url) => {
      this.registerUrl = url;
    });
  }

  handleInput(e) {
    const field = e.currentTarget.dataset.field;
    if (field !== "username" && field !== "password") return;
    this[field] = e.target.value;
  }

  togglePassword() {
    this.showPassword = !this.showPassword;
  }

  async handleSubmit(e) {
    e.preventDefault();
    this.error = "";

    if (!this.username.trim() || !this.password) {
      this.error = "Please enter your username and password.";
      return;
    }

    this.loading = true;
    try {
      const result = await login({
        username: this.username,
        password: this.password,
        startUrl: this.startUrl
      });
      this.loading = false;

      if (!result.isLoggedIn) {
        this.error = result.message || "Invalid credentials. Please try again.";
        return;
      }

      if (result.redirectUrl) {
        // Redirection serveur (ex: change de mot de passe, SSO) — rechargement complet.
        window.location.href = result.redirectUrl;
        return;
      }

      // Session établie : on navigue vers la page d'accueil du site.
      this.navigateTo(this.homePageName);
    } catch (err) {
      this.loading = false;
      console.error("customLogin login error:", err);
      const body = err && err.body;
      const serverMsg =
        (body && (body.message || body.output)) ||
        (err && err.message) ||
        "";
      this.error = this.friendlyError(serverMsg);
    }
  }

  goForgot(e) {
    if (e.type === "keydown" && e.key !== "Enter" && e.key !== " ") return;
    e.preventDefault();
    this.navigateTo(this.forgotPageName);
  }

  goRegister(e) {
    if (e.type === "keydown" && e.key !== "Enter" && e.key !== " ") return;
    e.preventDefault();
    this.navigateTo(this.registerPageName);
  }

  navigateTo(pageName) {
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: { name: pageName }
    });
  }

  friendlyError(raw) {
    const msg = raw && typeof raw === "string" ? raw : "";
    const technical = /apex request is invalid|internal server error|insufficient|session|invalid|exception|error while/i;
    if (!msg || technical.test(msg)) {
      return "Unable to sign in right now. Please try again.";
    }
    return msg;
  }
}