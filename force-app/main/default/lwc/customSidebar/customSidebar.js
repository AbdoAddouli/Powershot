import { LightningElement, api, wire } from "lwc";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import logout from "@salesforce/apex/PowerShotLoginController.logout";
import USER_ID from "@salesforce/user/Id";
import NAME_FIELD from "@salesforce/schema/User.Name";
import EMAIL_FIELD from "@salesforce/schema/User.Email";

export default class CustomSidebar extends NavigationMixin(LightningElement) {
  @api userName;
  @api userEmail;

  @wire(CurrentPageReference)
  currentPageRef;

  collapsed = false;
  profileOpen = false;

  navItems = [
    {
      key: "home",
      label: "Home",
      pageName: "Home",
      icon: "home",
      active: false
    },
    {
      key: "dashboard",
      label: "Dashboard",
      pageName: "Dashboard__c",
      icon: "dashboard",
      active: false
    },
    {
      key: "wells",
      label: "Wells & Production",
      pageName: "Wells_and_Production__c",
      icon: "well",
      active: false
    },
    {
      key: "billing",
      label: "Billing & Royalties",
      pageName: "Billing_and_Royalties__c",
      icon: "billing",
      active: false
    },
    {
      key: "compliance",
      label: "Compliance",
      pageName: "Compliance__c",
      icon: "compliance",
      active: false
    },
    {
      key: "hse",
      label: "HSE",
      pageName: "HSE__c",
      icon: "hse",
      active: false
    }
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

  get sidebarClass() {
    return "ps-sidebar" + (this.collapsed ? " ps-sidebar-collapsed" : "");
  }

  get collapseAriaLabel() {
    return this.collapsed ? "Expand sidebar" : "Collapse sidebar";
  }

  get chevronClass() {
    return (
      "ps-side-chevron" + (this.profileOpen ? " ps-side-chevron-open" : "")
    );
  }

  get expanded() {
    return this.collapsed === false;
  }

  get decoratedNavItems() {
    return this.navItems.map((item) => ({
      ...item,
      className: "ps-side-link" + (item.active ? " ps-side-active" : ""),
      ariaCurrent: item.active ? "page" : undefined,
      linkTitle: this.collapsed ? item.label : undefined,
      isHome: item.icon === "home",
      isDashboard: item.icon === "dashboard",
      isWell: item.icon === "well",
      isBilling: item.icon === "billing",
      isCompliance: item.icon === "compliance",
      isHse: item.icon === "hse"
    }));
  }

  connectedCallback() {
    this.syncActiveFromContext();
  }

  syncActiveFromContext() {
    // Source fiable : la page courante fournie par la navigation (LWC).
    const ref = this.currentPageRef;
    let pageName = null;
    if (ref && ref.attributes && ref.attributes.name) {
      pageName = ref.attributes.name;
    }
    if (pageName && this.navItems.some((i) => i.pageName === pageName)) {
      this.setActive(pageName);
      return;
    }
    // Fallback : analyse du chemin d'URL.
    this.syncActiveFromUrl();
  }

  syncActiveFromUrl() {
    const path = window.location.pathname.toLowerCase();
    const match = this.navItems.find((item) =>
      this.matchesUrl(item, path)
    );
    this.setActive(match ? match.pageName : null);
  }

  matchesUrl(item, path) {
    if (!path) return false;
    const lc = item.pageName.toLowerCase();
    const noC = lc.replace(/__c$/, "");
    const markers = new Set([
      lc,
      noC,
      noC.replace(/_/g, "-"),
      (item.label || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
    ]);
    for (const marker of markers) {
      if (marker && path.includes(marker)) return true;
    }
    return false;
  }

  handleNavClick(e) {
    const pageName = e.currentTarget.dataset.page;
    if (!pageName) return;
    this.setActive(pageName);
    this.navigateToPage(pageName);
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
    this.navigateToPage("Profile__c");
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

  toggleCollapse() {
    this.collapsed = !this.collapsed;
    if (this.collapsed) this.profileOpen = false;
  }

  toggleProfileMenu(event) {
    if (this.collapsed) return;
    if (event && typeof event.stopPropagation === "function") {
      event.stopPropagation();
    }
    this.profileOpen = !this.profileOpen;
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
    if (!this.profileOpen) return;
    const path = (e.composedPath && e.composedPath()) || [];
    const userBtn = this.template.querySelector(".ps-side-user");
    const menu = this.template.querySelector(".ps-side-user-menu");
    const hitsInside = [userBtn, menu].some(
      (el) => el != null && path.includes(el)
    );
    if (hitsInside) return;
    this.profileOpen = false;
  }
}
