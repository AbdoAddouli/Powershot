import { LightningElement, wire } from "lwc";
import getMarketData from "@salesforce/apex/MarketDataController.getMarketData";
import getSupplyAgreementPricing from "@salesforce/apex/MarketDataController.getSupplyAgreementPricing";

export default class MarketDataHome extends LightningElement {
  prices = [];
  stocks = [];
  asOf = "";
  hasError = false;
  errorMessage = "";
  commodityGroups = [];
  pricingError = false;

  @wire(getMarketData)
  wiredMarketData({ error, data }) {
    if (data) {
      this.prices = (data.prices || []).map((p) => ({
        commodity: p.commodity,
        rawPrice: p.price != null ? Number(p.price) : null,
        formatted: p.price != null ? this.formatCurrency(p.price) : "—"
      }));
      this.applyBarWidths();
      this.stocks = (data.stocks || []).map((s) => ({
        product: s.product || "—",
        nationalStock:
          s.nationalStock != null ? this.formatNumber(s.nationalStock) : "—",
        localVolume:
          s.localVolume != null ? this.formatNumber(s.localVolume) : "—"
      }));
      this.asOf = data.asOf ? new Date(data.asOf).toLocaleString() : "";
      this.hasError = false;
    } else if (error) {
      this.hasError = true;
      this.errorMessage = error.body?.message || "Failed to load market data.";
    }
  }

  @wire(getSupplyAgreementPricing)
  wiredAgreementPricing({ error, data }) {
    if (data) {
      this.commodityGroups = data.map((group) => {
        const spot = group.spotPrice;
        const sorted = [...(group.agreements || [])].sort((a, b) => {
          const va = a.variance != null ? Number(a.variance) : -Infinity;
          const vb = b.variance != null ? Number(b.variance) : -Infinity;
          return vb - va;
        });
        return {
          commodity: group.commodity,
          spotPrice: spot != null ? this.formatCurrency(spot) : "—",
          agreements: sorted.map((ag) => ({
            id: ag.id,
            name: ag.name || "—",
            account: ag.account || "—",
            currentPrice:
              ag.currentPrice != null
                ? this.formatCurrency(ag.currentPrice)
                : "—",
            spotPrice:
              ag.spotPrice != null ? this.formatCurrency(ag.spotPrice) : "—",
            benchmark: ag.benchmark || "—",
            source: ag.source || "—",
            lastSync: ag.lastSync
              ? new Date(ag.lastSync).toLocaleDateString()
              : "—",
            variance:
              ag.variance != null ? this.formatVariance(ag.variance) : "—",
            varianceClass:
              ag.variance != null ? this.varianceClass(ag.variance) : "",
            priceChange:
              ag.priceChange != null
                ? this.formatVariance(ag.priceChange)
                : "—",
            priceChangeClass:
              ag.priceChange != null ? this.varianceClass(ag.priceChange) : ""
          }))
        };
      });
      this.pricingError = false;
    } else if (error) {
      this.pricingError = true;
    }
  }

  formatCurrency(value) {
    return Number(value).toLocaleString("en-US", {
      style: "currency",
      currency: "USD"
    });
  }

  formatNumber(value) {
    return Number(value).toLocaleString("en-US");
  }

  applyBarWidths() {
    const max = Math.max(...this.prices.map((p) => p.rawPrice ?? 0));
    if (max <= 0) return;
    this.prices = this.prices.map((p) => ({
      ...p,
      percent: Math.round(((p.rawPrice ?? 0) / max) * 100)
    }));
  }

  get hasPrices() {
    return this.prices.length > 0;
  }

  get hasStocks() {
    return this.stocks.length > 0;
  }

  get hasCommodityGroups() {
    return this.commodityGroups.length > 0;
  }

  formatVariance(value) {
    const num = Number(value);
    const sign = num > 0 ? "+" : "";
    return sign + num.toFixed(2) + "%";
  }

  varianceClass(value) {
    const num = Number(value);
    if (num > 0) return "variance-positive";
    if (num < 0) return "variance-negative";
    return "variance-neutral";
  }
}
