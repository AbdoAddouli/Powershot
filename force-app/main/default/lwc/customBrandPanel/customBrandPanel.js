import { LightningElement, api } from "lwc";
import oilRigHero from "@salesforce/resourceUrl/oilRigHero";
import windTurbineHero from "@salesforce/resourceUrl/windTurbineHero";

export default class CustomBrandPanel extends LightningElement {
  @api variant = "oil";

  heroImages = {
    oil: oilRigHero,
    renewable: windTurbineHero
  };

  get image() {
    return this.heroImages[this.variant] || oilRigHero;
  }
}