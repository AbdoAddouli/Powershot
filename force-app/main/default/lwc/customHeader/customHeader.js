import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import logout from "@salesforce/apex/PowerShotLoginController.logout";
import USER_ID from "@salesforce/user/Id";
import NAME_FIELD from "@salesforce/schema/User.Name";
import EMAIL_FIELD from "@salesforce/schema/User.Email";

export default class CustomHeader extends NavigationMixin(LightningElement) {
  @api userName;
  @api userEmail;

  profileOpen = false;
  mobileOpen = false;

  navItems = [
    { key: "home", label: "Home", pageName: "Home", active: false },
    {
      key: "dashboard",
      label: "Dashboard",
      pageName: "Dashboard",
      active: false
    },
    {
      key: "wells",
      label: "Wells & Production",
      pageName: "Wells_Production",
      active: false
    },
    {
      key: "billing",
      label: "Billing & Royalties",
      pageName: "Billing_Royalties",
      active: false
    },
    {
      key: "compliance",
      label: "Compliance",
      pageName: "Compliance",
      active: false
    },
    { key: "hse", label: "HSE", pageName: "HSE", active: false }
  ];

  @wire(getRecord, { recordId: USER_ID, fields: [NAME_FIELD, EMAIL_FIELD] })
  userRecord;

  get displayName() {
    if (this.userName) return this.userName;
    const name = getFieldValue(this.userRecord.data, NAME_FIELD);
    return name || "Partner";
  }

  get displayEmail() {
    if (this.userEmail) return this.userEmail;
    return getFieldValue(this.userRecord.data, EMAIL_FIELD) || "";
  }

  get userInitial() {
    const name = this.displayName.trim();
    return name ? name.charAt(0).toUpperCase() : "?";
  }

  get chevronClass() {
    return "ps-chevron" + (this.profileOpen ? " ps-chevron-open" : "");
  }

  get mobileMenuLabel() {
    return this.mobileOpen ? "Close navigation menu" : "Open navigation menu";
  }

  get decoratedNavItems() {
    return this.navItems.map((item) => ({
      ...item,
      className: "ps-nav-link" + (item.active ? " ps-nav-active" : ""),
      ariaCurrent: item.active ? "page" : undefined,
      mobileClassName:
        "ps-mobile-link" + (item.active ? " ps-mobile-active" : "")
    }));
  }

  get burgerLine1() {
    return "ps-burger-line" + (this.mobileOpen ? " ps-burger-open-1" : "");
  }

  get burgerLine2() {
    return "ps-burger-line" + (this.mobileOpen ? " ps-burger-open-2" : "");
  }

  get burgerLine3() {
    return "ps-burger-line" + (this.mobileOpen ? " ps-burger-open-3" : "");
  }

  connectedCallback() {
    // État actif aligné sur la page réellement affichée (refresh, back/forward).
    this.syncActiveFromUrl();
  }

  syncActiveFromUrl() {
    const path = window.location.pathname.toLowerCase();
    const match = this.navItems.find((item) =>
      path.includes(item.pageName.toLowerCase())
    );
    this.setActive(match ? match.pageName : null);
  }

  handleNavClick(e) {
    const pageName = e.currentTarget.dataset.page;
    if (!pageName) return;
    this.setActive(pageName);
    this.navigateToPage(pageName);
  }

  handleMobileNavClick(e) {
    const pageName = e.currentTarget.dataset.page;
    if (!pageName) return;
    this.setActive(pageName);
    this.navigateToPage(pageName);
    this.mobileOpen = false;
  }

  goHome() {
    this.setActive("Home");
    this.navigateToPage("Home");
  }

  handleLogoKey(e) {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      this.goHome();
    }
  }

  goProfile() {
    this.profileOpen = false;
    this.navigateToPage("Profile");
  }

  async handleLogout() {
    this.profileOpen = false;
    try {
      const url = await logout();
      if (url) {
        // Consommer le logout côté serveur (invalide la session) SANS que
        // logout.jsp choisisse la page d'arrivée (il forcerait /s/login/).
        await fetch(url, { method: "GET", credentials: "include" });
      }
    } catch {
      // Échec silencieux : on retombe sur la page Login du portail.
    }
    // Déchargement complet vers NOTRE page Login custom (page nommée "Login",
    // ex: /PowerShot/login), pas la login page système /s/login/.
    try {
      const loginUrl = await this[NavigationMixin.GenerateUrl]({
        type: "comm__namedPage",
        attributes: { name: "Login" }
      });
      if (loginUrl) {
        window.location.href = loginUrl;
        return;
      }
    } catch {
      // ignore : on bascule en navigation SPA ci-dessous.
    }
    this.navigateToPage("Login");
  }

  navigateToPage(pageName) {
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: { name: pageName }
    });
  }

  setActive(pageName) {
    this.navItems = this.navItems.map((item) => ({
      ...item,
      active: item.pageName === pageName
    }));
  }

  toggleProfileMenu() {
    this.profileOpen = !this.profileOpen;
  }

  toggleMobileMenu() {
    this.mobileOpen = !this.mobileOpen;
  }

  renderedCallback() {
    if (!this._clickHandlerBound) {
      this._clickHandlerBound = true;
      this._docClickHandler = this.handleDocClick.bind(this);
      document.addEventListener("click", this._docClickHandler);
    }
  }

  disconnectedCallback() {
    if (this._docClickHandler) {
      document.removeEventListener("click", this._docClickHandler);
    }
  }

  handleDocClick(e) {
    if (this.profileOpen) {
      const trigger = this.template.querySelector(".ps-profile-trigger");
      const menu = this.template.querySelector(".ps-profile-menu");
      const inside =
        (trigger && trigger.contains(e.target)) ||
        (menu && menu.contains(e.target));
      if (!inside) this.profileOpen = false;
    }

    if (this.mobileOpen) {
      const burger = this.template.querySelector(".ps-hamburger");
      const mobileMenu = this.template.querySelector(".ps-mobile-menu");
      const inside =
        (burger && burger.contains(e.target)) ||
        (mobileMenu && mobileMenu.contains(e.target));
      if (!inside) this.mobileOpen = false;
    }
  }
}