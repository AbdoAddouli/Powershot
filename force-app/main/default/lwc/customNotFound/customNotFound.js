import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import isAuthenticated from "@salesforce/apex/PowerShotLoginController.isAuthenticated";

export default class CustomNotFound extends NavigationMixin(LightningElement) {
  @api variant = "oil";
  @api homePageName = "Home";
  @api loginPageName = "Login";

  isLoggedIn = false;
  checking = true;

  homeUrl = "";
  loginUrl = "";

  connectedCallback() {
    this[NavigationMixin.GenerateUrl]({
      type: "comm__namedPage",
      attributes: { name: this.homePageName }
    }).then((url) => {
      this.homeUrl = url;
    });
    this[NavigationMixin.GenerateUrl]({
      type: "comm__namedPage",
      attributes: { name: this.loginPageName }
    }).then((url) => {
      this.loginUrl = url;
    });

    isAuthenticated()
      .then((auth) => {
        this.isLoggedIn = auth;
        this.checking = false;
      })
      .catch(() => {
        this.isLoggedIn = false;
        this.checking = false;
      });
  }

  goBack() {
    if (window.history.length > 1) {
      window.history.back();
    } else if (this.homeUrl) {
      window.location.href = this.homeUrl;
    }
  }

  goHome(e) {
    if (e.type === "keydown" && e.key !== "Enter" && e.key !== " ") return;
    e.preventDefault();
    if (this.homeUrl) {
      window.location.href = this.homeUrl;
    }
  }

  goLogin(e) {
    if (e.type === "keydown" && e.key !== "Enter" && e.key !== " ") return;
    e.preventDefault();
    if (this.loginUrl) {
      window.location.href = this.loginUrl;
    }
  }
}