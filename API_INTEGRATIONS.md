# API Integrations for Salesforce Energy Project

A curated list of real, working external APIs that align with this project's upstream, midstream, downstream, and HSE domains. Each API is free or has a meaningful free tier, requires no paid subscriptions to start, and provides data relevant to the business processes in this org.

---

## 1. OilPriceAPI — Commodity Pricing

| Property | Detail |
|---|---|
| **URL** | `https://oilpriceapi.com` |
| **Docs** | `https://oilpriceapi.com/docs` |
| **Auth** | Token-based (free key, no CC) |
| **Free Tier** | 1,000 requests/month |
| **Rate Limit** | 10 req/min |
| **Format** | JSON |
| **Updated** | Every 5 minutes |

**Description**  
Normalized REST API for 60+ energy and agricultural commodity prices from ICE, CME, and 20+ exchanges. Provides spot and futures prices for WTI, Brent, gasoline, diesel, natural gas, heating oil, and more.

**Key Endpoints**
```
GET /v1/prices/latest?by_code=BRENT_CRUDE_USD
GET /v1/prices/?by_code=WTI_CRUDE_USD&period=day&page_size=10
```

**Integration Points**
- `RoyaltyCalculationService` — use real-time pricing to compute `Allocated_Revenue__c`
- `ProductionAllocationService` — value produced volumes at market rates
- LWC dashboards — display current WTI/Brent spot prices

---

## 2. EIA API — U.S. Energy Information Administration

| Property | Detail |
|---|---|
| **URL** | `https://api.eia.gov/v2/` |
| **Docs** | `https://www.eia.gov/opendata/documentation.php` |
| **Auth** | API key (free, register at `https://www.eia.gov/opendata/`) |
| **Free Tier** | Unlimited (throttled) |
| **Rate Limit** | ~5 req/sec; 5,000 row cap per response |
| **Format** | JSON, XML |
| **Version** | v2.1.12 (Mar 2026) |

**Description**  
Official U.S. government energy statistics API covering petroleum, natural gas, electricity, coal, nuclear, and renewable energy. 2M+ data series organized in a hierarchical tree.

**Key Endpoints**
```
GET /v2/petroleum/crd/crpdn/data/?api_key=KEY&frequency=monthly
GET /v2/natural-gas/cons/sum/data/?api_key=KEY
GET /v2/petroleum/stoc/st/data/?api_key=KEY        # Weekly inventory
```

**Data Series Available**
- Crude oil production by state/PAD district (monthly/annual)
- Natural gas storage & consumption
- Weekly petroleum supply & inventory estimates
- Refinery inputs & utilization
- Spot & futures prices (daily/weekly/monthly)
- Import/export volumes by country

**Integration Points**
- `InventoryBalanceService` — benchmark `Current_Volume__c` and `Minimum_Threshold__c` against PAD district averages
- `PipelineIntegrityService` — correlate inspection schedules with regional supply data
- Compliance reporting — cross-reference EIA production data for regulatory submissions
- `EIAPricingService` — syncs retail fuel prices and national stock benchmarks to `Supply_Agreement__c.Current_Price__c` and `Fuel_Inventory__c.EIA_National_Stock__c` on weekly schedule (Thu 2:30 PM). Product codes: Refined→`EER_EPMRU_PF4_Y44NY_DPG`, Gas→`EER_EPMRU_PF4_Y35NY_DPG`, Diesel→`EPDXL0`, Jet Fuel→`EPJK`, Heating Oil→`EPMM`

---

## 3. EPA ECHO Web Services — Environmental Compliance

| Property | Detail |
|---|---|
| **URL** | `https://echo.epa.gov/tools/web-services` |
| **Docs** | ECHO web services documentation on site |
| **Auth** | None required (or `api.data.gov` key for higher volume) |
| **Free Tier** | Unlimited |
| **Rate Limit** | Reasonable use |
| **Format** | JSON, XML, JSONP |

**Description**  
EPA's Enforcement and Compliance History Online provides REST services for facility compliance across Clean Air Act (CAA), Clean Water Act (CWA), RCRA hazardous waste, and Safe Drinking Water Act (SDWA). Returns inspection history, violation status, enforcement actions, and penalty data.

**Key Endpoints**
```
GET /rest/air/facility?name=Exxon              # Air compliance
GET /rest/water/facility?name=Company           # Wastewater/NPDES
GET /rest/hazardous-waste/facility?name=        # RCRA hazardous waste
GET /rest/drinking-water/system?name=           # SDWA public water
GET /rest/enforcement/case?name=                # Civil/criminal enforcement
```

**Integration Points**
- `HSEIncidentService` — verify regulatory reportability thresholds against EPA enforcement history
- `ComplianceDueDateService` — cross-reference permit status with EPA facility compliance records
- Pipeline integrity — check CAA violations at pipeline facilities
- LWC widgets — display compliance scorecards for assets and facilities

---

## 4. EPA Envirofacts Data Service — Environmental Data

| Property | Detail |
|---|---|
| **URL** | `https://data.epa.gov/dmapservice/` |
| **Docs** | `https://www.epa.gov/enviro/envirofacts-data-service-api` |
| **Auth** | None required |
| **Free Tier** | Unlimited |
| **Rate Limit** | 15-minute query timeout |
| **Format** | JSON, CSV, Excel, XML, Parquet, PDF |

**Description**  
Single-point access to 20+ EPA databases including Toxics Release Inventory (TRI), Superfund (SEMS), RCRAInfo, SDWIS, Biennial Reporting, and UV Index. RESTful query-by-table interface with multiple output formats.

**Key Endpoints**
```
GET /dmapservice/tri_facility/statecd=TX/         # TRI releases by state
GET /dmapservice/rcra_evaluation/                # RCRA inspection/evaluation
GET /dmapservice/sems_site/                      # Superfund sites
GET /getEnvirofactsUVDAILY/ZIP/77001/JSON        # UV Index
```

**Integration Points**
- HSE spill reporting — validate against TRI release data
- Well abandonment — check Superfund proximity for `getWellsDueForAbandonment`
- Environmental impact classification — reference spill volumes against historical TRI data

---

## 5. OpenWeatherMap — Weather Data

| Property | Detail |
|---|---|
| **URL** | `https://api.openweathermap.org` |
| **Docs** | `https://openweathermap.org/api` |
| **Auth** | API key (free, register on site) |
| **Free Tier** | 60 calls/min, 1,000,000 calls/month |
| **Rate Limit** | 60 req/min |
| **Format** | JSON, XML, HTML |

**Description**  
Global weather data from satellites, radar, weather stations, and models. Current conditions, 5-day/3-hour forecasts, air pollution index, and 15 weather map layers. Covers 200,000+ cities worldwide.

**Key Endpoints**
```
GET /data/2.5/weather?lat=30.26&lon=-97.74&appid=KEY    # Current weather
GET /data/2.5/forecast?lat=30.26&lon=-97.74&appid=KEY   # 5-day forecast
GET /data/2.5/air_pollution?lat=30.26&lon=-97.74&appid=KEY
```

**Integration Points**
- Well operations — flag weather windows for drilling/workover activities
- Pipeline integrity — monitor temperature/precipitation for pipeline stress assessments
- HSE incident correlation — analyze weather conditions at time of incident
- LWC dashboards — display site weather on well/pipeline/terminal record pages
- Inventory logistics — weather-aware delivery scheduling for fuel terminals

---

## 6. Sodir FactPages (Norwegian Petroleum Directorate) — Open Petroleum Data

| Property | Detail |
|---|---|
| **URL** | `https://github.com/kkollsga/factpages-py` (Python client) |
| **Docs** | `https://www.sodir.no/en/` |
| **Auth** | None required (open data) |
| **Free Tier** | Unlimited |
| **Format** | JSON (via Python library or direct API) |

**Description**  
Comprehensive petroleum data from the Norwegian Continental Shelf: 75+ datasets covering fields, discoveries, wellbores, facilities, pipelines, licenses, production volumes, seismic surveys, and stratigraphy. Maintained by the Norwegian Offshore Directorate (Sodir).

**Available Datasets (selection)**
| Category | Examples |
|---|---|
| Core Entities | field, discovery, wellbore, facility |
| Company | operator, licensee information |
| Licensing | licence, licence_licensee_hst |
| Field Details | field_reserves, field_licensee_hst |
| Wellbore Details | wellbore_core, wellbore_dst, wellbore_formation_top |
| Facility Details | facility_function, pipeline |
| Seismic | seismic_acquisition |

**Integration Points**
- Well lifecycle modeling — compare field-level production curves against Norwegian analogues
- Production benchmarking — validate `Production_Allocation__c` volumes against regional averages
- Geological correlation — wellbore formation tops for drilling planning

---

## 7. OilPriceAPI FracFocus — Hydraulic Fracturing Chemical Disclosure

| Property | Detail |
|---|---|
| **URL** | `https://www.oilpriceapi.com/data/fracfocus` |
| **Auth** | Included in OilPriceAPI free tier |
| **Free Tier** | 1,000 requests/month (shared with OilPriceAPI) |
| **Format** | JSON |

**Description**  
Programmatic access to 242,000+ FracFocus chemical disclosure records covering well completions across major U.S. oil and gas producing states. Updated monthly from the official FracFocus registry. Query by operator, state, chemical, date range.

**Key Endpoints**
```
GET /v1/ei/fracfocus?state=TX&operator=Pioneer&limit=10
GET /v1/ei/fracfocus?chemical=benzene&state=ND
```

**Integration Points**
- Well completion transparency — disclose fracturing chemicals per well
- HSE chemical tracking — cross-reference `HSE_Incident__c` spills with disclosed chemicals
- Regulatory compliance — automate chemical disclosure reporting

---

## Integration Architecture Notes

### Calling APIs from Salesforce
1. **Apex Callouts** — Use `HttpRequest`/`HttpResponse` classes for synchronous calls (limits: 100 callouts/transaction)
2. **Named Credentials** — Store API keys securely; use Auth. Provider for token management
3. **Scheduled Apex** — For periodic data sync (e.g., daily EIA price update)
4. **Platform Events** — Decouple API calls from trigger logic for long-running requests
5. **External Services** — Register OpenAPI specs to call APIs declaratively from Flow

### Recommended Order of Implementation

| Phase | API | Business Value |
|---|---|---|
| 1 | OilPriceAPI | Instant revenue/royalty pricing |
| 2 | OpenWeatherMap | Operational weather safety |
| 3 | EIA | Supply benchmarking & compliance |
| 4 | EPA ECHO | HSE compliance verification |
| 5 | EPA Envirofacts | Environmental impact analysis |
| 6 | FracFocus | Well completion transparency |
| 7 | Sodir | International production benchmarking |

### Security Considerations
- Store API keys in Named Credentials, never in code
- Use `Cache.Session` for frequently accessed static data (e.g., daily prices)
- Implement `HttpCalloutMock` in test classes for all callout coverage
- Respect rate limits — implement retry with exponential backoff
- Cache responses in Custom Settings or Platform Cache to reduce API consumption
