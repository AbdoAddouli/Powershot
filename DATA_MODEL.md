# Oil & Gas Salesforce Project — Data Model & Complete Reference

**Target Orgs:**
- `addouliabdo9.76deae143000@agentforce.com` (ouil gas) — main deployed org
- `abdo@analytics.com` (oil-gas_project) — working org for LWC testing

**API Version:** 66.0  
**Last Updated:** July 2026

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Custom Objects](#2-custom-objects)
3. [Enhanced Standard Objects](#3-enhanced-standard-objects)
4. [Object Relationship Architecture](#4-object-relationship-architecture)
5. [Apex Classes](#5-apex-classes)
6. [Triggers](#6-triggers)
7. [LWC Components](#7-lwc-components)
8. [Flows](#8-flows)
9. [Permission Sets](#9-permission-sets)
10. [External Credentials & Named Credentials](#10-external-credentials--named-credentials)
11. [Flexipages (Record Pages)](#11-flexipages-record-pages)
12. [Layouts](#12-layouts)
13. [Integrations & APIs](#13-integrations--apis)
14. [Security Model](#14-security-model)
15. [Key Business Processes](#15-key-business-processes)
16. [Deployment Commands](#16-deployment-commands)

---

## 1. Project Overview

Integrated Salesforce architecture covering **Upstream (E&P)**, **Midstream**, and **Downstream** segments of the Oil & Gas industry.

| Property | Value |
|---|---|
| **Domain** | Oil & Gas (Integrated — All Segments) |
| **Org Type** | New greenfield org (Developer Edition) |
| **Salesforce API** | v66.0 |
| **Custom Objects** | 27 |
| **Apex Classes** | 56 |
| **Triggers** | 8 |
| **LWC Components** | 10 |
| **Flows** | 11 |
| **Permission Sets** | 18 |
| **External Credentials** | 6 |
| **Named Credentials** | 8 |
| **Flexipages** | 8 |
| **Layouts** | 25 |
| **Tabs** | 25 |

---

## 2. Custom Objects

### 2.1 API_Key_Settings__c

**Label:** API Key Settings  
**Description:** Stores API keys for external service authentication.

| Field | Type | Description |
|---|---|---|
| Name | Text (80) | Record name |
| OilPrice_API_Key__c | Text | API key for oilprice.com commodity pricing |

---

### 2.2 Compliance_Report__c

**Label:** Compliance Report  
**Description:** Tracks regulatory compliance report submissions to agencies (EPA, state, local).

| Field | Type | Description |
|---|---|---|
| Name | Text (80) | Auto-generated report name |
| Report_Type__c | Picklist | Type of compliance report |
| Regulatory_Permit__c | Lookup(Regulatory_Permit__c) | Related permit |
| Due_Date__c | Date | Submission deadline |
| Submitted_Date__c | Date | Date submitted |
| Status__c | Picklist | Submitted / Pending / Waived / Overdue |
| Regulatory_Body__c | Text | Agency receiving the report |
| Assigned_To__c | Lookup(User) | Responsible person |
| Days_Overdue__c | Formula | Calculated days past due |
| Account__c | Lookup(Account) | Operator account |

---

### 2.3 Fuel_Inventory__c

**Label:** Fuel Inventory  
**Description:** Tracks fuel/product inventory levels at terminals and retail outlets.

| Field | Type | Description |
|---|---|---|
| Name | Text (80) | Record name |
| Terminal__c | Lookup(Terminal__c) | Terminal location |
| Retail_Outlet__c | Lookup(Retail_Outlet__c) | Retail outlet |
| Product__c | Picklist | Product type |
| Tank_Number__c | Text | Tank identifier |
| Tank_Capacity__c | Number(18,2) | Maximum capacity |
| Current_Volume__c | Number(18,2) | Current volume |
| Available_Volume__c | Number(18,2) | Available for sale |
| Last_Receipt_Date__c | Date | Last receipt date |
| Last_Delivery_Date__c | Date | Last delivery date |
| Minimum_Threshold__c | Number(18,2) | Reorder threshold |
| Gauge_Type__c | Picklist | Manual / Automatic / Radar |
| Status__c | Picklist | Active / Inactive / Under Maintenance |

---

### 2.4 GTM_Config__c

**Label:** GTM Config  
**Description:** Google Tag Manager configuration for marketing analytics.

| Field | Type | Description |
|---|---|---|
| Name | Text (80) | Record name |
| GTM_Container_ID__c | Text | GTM container identifier |
| GTM_Account_ID__c | Text | GTM account identifier |
| GA4_Property_ID__c | Text | Google Analytics 4 property ID |
| LinkedIn_Partner_ID__c | Text | LinkedIn insight tag ID |
| TikTok_Pixel_ID__c | Text | TikTok pixel ID |
| Snapchat_Pixel_ID__c | Text | Snapchat pixel ID |
| Slack_Webhook_URL__c | Text | Slack webhook URL for alerts |

---

### 2.5 HSE_Incident__c

**Label:** HSE Incident  
**Description:** Health, Safety & Environment incidents across all O&G segments.

| Field | Type | Description |
|---|---|---|
| Name | Auto-number | Incident reference number |
| Account__c | Lookup(Account) | Operator account |
| Well__c | Lookup(Well__c) | Related well |
| Pipeline__c | Lookup(Pipeline__c) | Related pipeline |
| Retail_Outlet__c | Lookup(Retail_Outlet__c) | Related outlet |
| Incident_Type__c | Picklist | Spill / Injury / Vehicle / Fire / Explosion / Safety Near Miss / Environmental |
| Incident_Date__c | Date | Date of incident |
| Severity__c | Picklist | Critical / High / Medium / Low |
| Location__c | Text | Incident location description |
| Description__c | Long Text Area | Incident description |
| Fatality_Occurred__c | Checkbox | Was there a fatality? |
| Injury_Type__c | Picklist | First Aid / Medical Treatment / Lost Time / Life-Threatening / Permanent Disability |
| LTI__c | Checkbox | Lost Time Incident |
| Recordable__c | Checkbox | OSHA recordable |
| Regulatory_Reportable__c | Checkbox | Must be reported to regulators |
| Spill_Volume__c | Number(18,2) | Volume of spill (bbls) |
| Environmental_Impact__c | Picklist | Minor / Moderate / Major |
| Root_Cause__c | Long Text Area | Root cause analysis |
| Corrective_Action__c | Long Text Area | Corrective actions taken |
| Status__c | Picklist | Open / Investigating / Remediation / Closed |

---

### 2.6 HSE_Observation__c

**Label:** HSE Observation  
**Description:** Safety observations (safe/unsafe acts and conditions).

| Field | Type | Description |
|---|---|---|
| Name | Auto-number | Observation reference |
| Account__c | Lookup(Account) | Operator account |
| Observation_Type__c | Picklist | Safe / Unsafe |
| Category__c | Picklist | Category of observation |
| Description__c | Long Text Area | Observation details |
| Location__c | Text | Where observed |
| Observer__c | Lookup(User) | Person who made observation |
| Corrective_Action_Taken__c | Long Text Area | Actions taken |
| Status__c | Picklist | Open / Closed |
| Pipeline__c | Lookup(Pipeline__c) | Related pipeline |

---

### 2.7 Inspection__c

**Label:** Inspection  
**Description:** Asset inspections for wells, pipelines, terminals, and equipment.

| Field | Type | Description |
|---|---|---|
| Name | Auto-number | Inspection reference |
| Pipeline__c | Lookup(Pipeline__c) | Inspected pipeline |
| Well__c | Lookup(Well__c) | Inspected well |
| Terminal__c | Lookup(Terminal__c) | Inspected terminal |
| Inspection_Type__c | Picklist | Visual / NDT / Cathodic / Hydrotest / Internal |
| Scheduled_Date__c | Date | Planned inspection date |
| Inspection_Date__c | Date | Actual inspection date |
| Completed_Date__c | Date | Date completed |
| Inspector__c | Lookup(User) | Assigned inspector |
| Result__c | Picklist | Pass / Fail / Conditional |
| Findings__c | Long Text Area | Inspection findings |
| Is_Recurring__c | Checkbox | Is this a recurring inspection? |
| Recurring_Interval_Days__c | Number(5,0) | Days between inspections |
| Parent_Inspection__c | Lookup(Inspection__c) | Parent inspection record |
| Next_Due_Date__c | Date | Calculated next inspection due date |
| Status__c | Picklist | Scheduled / In Progress / Completed / Cancelled / Overdue |

---

### 2.8 Inventory_Transaction__c

**Label:** Inventory Transaction  
**Description:** Records fuel inventory movements (receipts, deliveries, transfers, adjustments).

| Field | Type | Description |
|---|---|---|
| Name | Auto-number | Transaction reference |
| Fuel_Inventory__c | Lookup(Fuel_Inventory__c) | Related inventory record |
| Movement_Type__c | Picklist | Receipt / Delivery / Transfer / Adjustment / Loss |
| Transaction_Date__c | Date | Date of transaction |
| Volume_Before__c | Number(18,2) | Volume before transaction |
| Volume_Change__c | Number(18,2) | Volume change |
| Volume_After__c | Number(18,2) | Volume after transaction |
| Transacted_By__c | Lookup(User) | Person performing transaction |
| Notes__c | Long Text Area | Transaction notes |

---

### 2.9 Invoice__c

**Label:** Invoice  
**Description:** Invoices for JV billing, royalty payments, and service contracts.

| Field | Type | Description |
|---|---|---|
| Name | Auto-number | Invoice number |
| JV__c | Lookup(Joint_Venture__c) | Related joint venture |
| Amount__c | Currency | Invoice amount |
| Invoice_Date__c | Date | Invoice date |
| Status__c | Picklist | Draft / Sent / Paid / Overdue / Cancelled |
| Description__c | Long Text Area | Invoice description |

---

### 2.10 Joint_Venture__c

**Label:** Joint Venture  
**Description:** Manages JV partnerships including working interest, revenue interest, and accounting method.

| Field | Type | Description |
|---|---|---|
| Name | Text (80) | JV name |
| Account__c | Lookup(Account) | Operator account |
| Partners__c | Long Text Area | List of JV partners |
| Operator__c | Lookup(Account) | Operating partner |
| Working_Interest_Percent__c | Percent | Working interest share |
| Revenue_Interest_Percent__c | Percent | Revenue interest share |
| Accounting_Method__c | Picklist | GAAP / IFRS / Tax |
| Status__c | Picklist | Active / Inactive / Dissolved |
| JV_Agreement_Document__c | URL | Link to agreement document |

---

### 2.11 Land_Parcel__c

**Label:** Land Parcel  
**Description:** Land parcels with mineral and surface rights tracking.

| Field | Type | Description |
|---|---|---|
| Name | Text (80) | Parcel name/number |
| Account__c | Lookup(Account) | Owner account |
| County__c | Text | County location |
| State__c | Text | State location |
| Acreage__c | Number(18,2) | Total acreage |
| Mineral_Rights_Owner__c | Text | Owner of mineral rights |
| Surface_Rights_Owner__c | Text | Owner of surface rights |
| Legal_Description__c | Long Text Area | Legal property description |
| Coordinates__c | Text | GPS coordinates |

---

### 2.12 Lease__c

**Label:** Lease  
**Description:** Oil and gas lease contracts with royalty rates and term tracking.

| Field | Type | Description |
|---|---|---|
| Name | Auto-number ({0000}) | Lease number |
| Account__c | Lookup(Account) | Lessee/operator |
| Land_Parcel__c | Lookout(Land_Parcel__c) | Related land parcel |
| Lease_Type__c | Picklist | Paid-Up / Free / Net Profits |
| Royalty_Percent__c | Percent | Royalty rate |
| Working_Interest_Percent__c | Percent | Working interest |
| Revenue_Interest_Percent__c | Percent | Net revenue interest |
| Term_Years__c | Number(3,0) | Primary term in years |
| Primary_Term_End__c | Date | End of primary term |
| Delay_Rental_Amount__c | Currency | Annual delay rental |
| Lease_End_Date__c | Date | Lease expiration date |
| Status__c | Picklist | Active / Expired / Terminated |

---

### 2.13 Measurement__c

**Label:** Measurement  
**Description:** Pipeline and terminal operational readings (flow, pressure, temperature).

| Field | Type | Description |
|---|---|---|
| Name | Auto-number | Reading reference |
| Pipeline__c | Lookup(Pipeline__c) | Related pipeline |
| Pipeline_Station__c | Lookup(Pipeline_Station__c) | Related station |
| Terminal__c | Lookup(Terminal__c) | Related terminal |
| Reading_DateTime__c | DateTime | Timestamp of reading |
| Gross_Volume__c | Number(18,2) | Gross volume |
| Net_Volume__c | Number(18,2) | Net volume |
| Temperature__c | Number(18,2) | Temperature (F) |
| Pressure__c | Number(18,2) | Pressure (psi) |
| Gravity__c | Number(18,2) | API gravity |
| BSandW_Percent__c | Percent | Basic sediment & water |
| Meter_Factor__c | Number(18,4) | Meter calibration factor |
| Source__c | Picklist | Custody Transfer / Check / SCADA |

---

### 2.14 Permit_to_Work__c

**Label:** Permit to Work  
**Description:** Safety permit system for hazardous work with isolation verification, gas testing, and multi-level authorization.

| Field | Type | Description |
|---|---|---|
| Name | Auto-number | PTW number |
| Well__c | Lookup(Well__c) | Well location |
| Pipeline_Station__c | Lookup(Pipeline_Station__c) | Station location |
| Terminal__c | Lookup(Terminal__c) | Terminal location |
| Refinery__c | Lookup(Refinery__c) | Refinery location |
| PTW_Number__c | Text | Assigned permit number |
| Permit_Type__c | Picklist | Hot Work / Confined Space / Excavation / Work at Height / Electrical / Mechanical |
| Description__c | Long Text Area | Work description |
| Location__c | Text | Specific work location |
| Scope_of_Work__c | Long Text Area | Detailed scope |
| Risk_Level__c | Picklist | Low / Medium / High / Critical |
| Issuer__c | Lookup(User) | Permit issuer |
| Holder__c | Lookup(User) | Permit holder |
| Issuing_Authority__c | Text | Authority issuing permit |
| Start_DateTime__c | DateTime | Work start |
| End_DateTime__c | DateTime | Work end |
| Valid_From__c | DateTime | Permit valid from |
| Valid_To__c | DateTime | Permit valid until |
| Isolation_Required__c | Checkbox | Isolation needed? |
| Isolation_Verified__c | Checkbox | Isolation verified? |
| Energy_Isolation_Type__c | Picklist | Electrical / Mechanical / Pneumatic / Hydraulic / Thermal / Gravity |
| Lockout_Tagout_Completed__c | Checkbox | LOTO completed? |
| Zero_Energy_State_Verified__c | Checkbox | Zero energy verified? |
| Gas_Test_Required__c | Checkbox | Gas test needed? |
| Gas_Test_Completed__c | Checkbox | Gas test done? |
| Gas_Test_Result__c | Picklist | Pass / Fail / Not Required |
| Oxygen_Level_Pct__c | Number(5,2) | O2 level % |
| LEL_Pct__c | Number(5,2) | Lower explosive limit % |
| H2S_Level_Ppm__c | Number(8,2) | H2S level (ppm) |
| CO_Level_Ppm__c | Number(8,2) | Carbon monoxide (ppm) |
| Authorizer__c | Lookup(User) | Primary authorizer |
| Authorization_Date__c | DateTime | Date authorized |
| Authorizer_2__c | Lookup(User) | Second authorizer |
| Authorization_2_Date__c | DateTime | Second authorization date |
| Authorizer_3__c | Lookup(User) | Third authorizer |
| Authorization_3_Date__c | DateTime | Third authorization date |
| Status__c | Picklist | Requested / Issued / Active / Completed / Cancelled / Expired |

---

### 2.15 Pipeline__c

**Label:** Pipeline  
**Description:** Pipeline infrastructure assets with capacity, commodity, and integrity tracking.

| Field | Type | Description |
|---|---|---|
| Name | Text (80) | Pipeline name |
| Account__c | Lookup(Account) | Operator account |
| Segment_Length_Miles__c | Number(18,2) | Length in miles |
| Diameter_inches__c | Number(18,2) | Pipe diameter |
| Commodity__c | Picklist | Crude / Gas / NGL / Refined |
| Capacity_bpd__c | Number(18,2) | Capacity (bbls/day) |
| Operating_Pressure__c | Number(18,2) | Operating pressure (psi) |
| MAOP__c | Number(18,2) | Maximum allowable operating pressure (psi) |
| SHVS_Class_Location__c | Picklist | Class 1 / Class 2 / Class 3 / Class 4 |
| Last_Inspection_Date__c | Date | Most recent inspection |
| Required_Inspection_Interval_Months__c | Number(5,0) | Required inspection frequency |
| Compliance_Status__c | Picklist | Compliant / Non-Compliant / Unknown / Expired |
| Status__c | Picklist | Active / Idle / Decommissioned |

---

### 2.16 Pipeline_Station__c

**Label:** Pipeline Station  
**Description:** Pump stations, compressor stations, valve sites, and meter stations along pipelines.

| Field | Type | Description |
|---|---|---|
| Name | Text (80) | Station name |
| Pipeline__c | Lookup(Pipeline__c) | Parent pipeline |
| Station_Type__c | Picklist | Pump / Compressor / Valve / Meter |
| Capacity__c | Number(18,2) | Station capacity |
| Horsepower__c | Number(18,2) | Horsepower rating |
| Station_Location__c | Text | Location description |
| Status__c | Picklist | Active / Idle / Decommissioned |

---

### 2.17 Production_Allocation__c

**Label:** Production Allocation  
**Description:** Monthly production volume allocation by well with revenue distribution by working/revenue interest.

| Field | Type | Description |
|---|---|---|
| Name | Auto-number | Allocation reference |
| Well__c | Lookup(Well__c) | Production well |
| Lease__c | Lookup(Lease__c) | Related lease |
| Period_Start__c | Date | Allocation period start |
| Period_End__c | Date | Allocation period end |
| Oil_Volume_bbls__c | Number(18,2) | Oil volume (barrels) |
| Gas_Volume_MCF__c | Number(18,2) | Gas volume (MCF) |
| Water_Volume_bbls__c | Number(18,2) | Water volume (barrels) |
| Days_On_Production__c | Number(5,0) | Producing days in period |
| Allocated_Revenue__c | Currency | Allocated revenue amount |
| Severance_Tax__c | Currency | Severance tax amount |
| Working_Interest_Share__c | Percent | Working interest for this allocation |
| Net_Revenue_Interest_Share__c | Percent | Net revenue interest |

---

### 2.18 Refinery__c

**Label:** Refinery  
**Description:** Refinery assets with capacity and complexity data.

| Field | Type | Description |
|---|---|---|
| Name | Text (80) | Refinery name |
| Account__c | Lookup(Account) | Operator account |
| PADD_District__c | Picklist | Petroleum Administration for Defense District |
| Capacity_bpd__c | Number(18,2) | Processing capacity (bbls/day) |
| Nelson_Complexity_Index__c | Number(5,2) | Complexity index |
| Units_List__c | Long Text Area | Configuration units |
| Status__c | Picklist | Operating / Idle / Shutdown / Under Construction |

---

### 2.19 Regulatory_Permit__c

**Label:** Regulatory Permit  
**Description:** Environmental and safety permits from regulatory agencies.

| Field | Type | Description |
|---|---|---|
| Name | Text (80) | Permit name |
| Account__c | Lookup(Account) | Operator account |
| Well__c | Lookup(Well__c) | Permitted well |
| Pipeline__c | Lookup(Pipeline__c) | Permitted pipeline |
| Refinery__c | Lookup(Refinery__c) | Permitted refinery |
| Permit_Type__c | Picklist | SPCC / Title V / NSPS / NPDES / Underground Injection |
| Permit_Number__c | Text | Agency permit number |
| Agency__c | Picklist | EPA / State / Local |
| Issue_Date__c | Date | Date issued |
| Expiration_Date__c | Date | Expiration date |
| Status__c | Picklist | Active / Pending / Expired / Suspended / Revoked |
| Compliance_Status__c | Picklist | Compliant / Non-Compliant / Expired / Critical - Expiring Soon / Approaching Expiration |
| Responsible_Party__c | Lookup(User) | Person responsible |
| Facility__c | Text | Facility name |
| Renewal_Reminder__c | Formula | Renewal reminder date |
| Renewal_Reminder_Sent__c | Checkbox | Reminder sent? |

---

### 2.20 Retail_Outlet__c

**Label:** Retail Outlet  
**Description:** Retail fuel stations and convenience stores.

| Field | Type | Description |
|---|---|---|
| Name | Text (80) | Outlet name |
| Account__c | Lookup(Account) | Operator account |
| Contact__c | Lookup(Contact) | Manager contact |
| Outlet_Code__c | Text | Internal outlet code |
| Brand__c | Text | Fuel brand |
| Location__c | Text | Physical address |
| Store_Type__c | Picklist | Company / Dealer / Jobber |
| Fuel_Tank_Count__c | Number(3,0) | Number of fuel tanks |
| Fuel_Volume_Monthly__c | Number(18,2) | Monthly fuel volume |
| C_Store__c | Checkbox | Has convenience store? |
| Car_Wash__c | Checkbox | Has car wash? |
| Status__c | Picklist | Active / Inactive / Under Renovation |

---

### 2.21 Service_Contract__c

**Label:** Service Contract  
**Description:** Contracts with service providers (drilling, well service, inspection).

| Field | Type | Description |
|---|---|---|
| Name | Text (80) | Contract name |
| Account__c | Lookup(Account) | Contractor account |
| Contract_Type__c | Picklist | Drilling / Workover / Well Service / Inspection / Cleaning |
| Contractor__c | Lookup(Account) | Service provider |
| Scope_of_Work__c | Long Text Area | Work description |
| Value__c | Currency | Contract value |
| Start_Date__c | Date | Contract start |
| End_Date__c | Date | Contract end |
| Insurance_Requirements__c | Long Text Area | Insurance requirements |
| PO_Reference__c | Text | Purchase order reference |
| Status__c | Picklist | Draft / Active / Completed / Terminated |

---

### 2.22 Store__c

**Label:** Store  
**Description:** Retail store management (separate from O&G core — not part of powershot project).

| Field | Type | Description |
|---|---|---|
| Name | Text (80) | Store name |
| Status__c | Picklist | Active / Inactive |

---

### 2.23 Supply_Agreement__c

**Label:** Supply Agreement  
**Description:** Term and spot supply contracts for crude, gas, NGL, and refined products.

| Field | Type | Description |
|---|---|---|
| Name | Text (80) | Agreement name |
| Account__c | Lookup(Account) | Counterparty |
| Agreement_Type__c | Picklist | Term / Spot / Exchange |
| Commodity__c | Picklist | Crude / Gas / NGL / Refined / Diesel / Jet Fuel / Heating Oil |
| Volume__c | Number(18,2) | Contract volume |
| Price_Basis__c | Picklist | Fixed / Index-linked / Negotiated |
| Index__c | Text | Pricing index (e.g., WTI, Brent, HH) |
| Current_Price__c | Number(18,2) | Current commodity price (synced via API) |
| Price_Benchmark__c | Picklist | WTI / Brent / HH / TTF / JKM / Dubai / NYMEX |
| Previous_Price__c | Currency | Price before last sync |
| Price_Change__c | Formula (Number) | % change: `(Current_Price - Previous_Price) / Previous_Price * 100` |
| Last_Sync_DateTime__c | DateTime | Timestamp of last API sync |
| Price_Source__c | Picklist | OilPriceAPI / EIA / Manual / Platts / OPIS |
| Price_Frequency__c | Picklist | Real-Time / Daily / Weekly / Monthly / On-Demand |
| Contract_Price__c | Currency | Negotiated contract price (manual) |
| Price_Variance_Limit__c | Number(5) | Max % variance before alert (default: 5) |
| Term_Start__c | Date | Agreement start |
| Term_End__c | Date | Agreement end |
| Delivery_Point__c | Text | Delivery location |
| Credit_Terms__c | Text | Payment terms |
| Status__c | Picklist | Active / Expired / Terminated / Draft |

---

### 2.24 Terminal__c

**Label:** Terminal  
**Description:** Storage terminals with tank capacity and access modes.

| Field | Type | Description |
|---|---|---|
| Name | Text (80) | Terminal name/code |
| Account__c | Lookup(Account) | Operator account |
| Storage_Capacity_bbls__c | Number(18,2) | Total storage capacity |
| Commodity_Type__c | Picklist | Crude / Gas / NGL / Refined |
| Tank_Count__c | Number(5,0) | Number of tanks |
| Rail_Truck_Marine_Access__c | Multi-Select Picklist | Access modes |
| Status__c | Picklist | Active / Inactive / Under Maintenance |

---

### 2.25 Transportation_Nomination__c

**Label:** Transportation Nomination  
**Description:** Pipeline capacity nominations for shipping contracts.

| Field | Type | Description |
|---|---|---|
| Name | Auto-number | Nomination reference |
| Account__c | Lookup(Account) | Shipper |
| Pipeline__c | Lookup(Pipeline__c) | Transport pipeline |
| Nomination_Period__c | Date | Shipping period |
| Requested_Volume__c | Number(18,2) | Volume requested |
| Confirmed_Volume__c | Number(18,2) | Volume confirmed |
| Shipper__c | Lookup(Account) | Shipping entity |
| Contract_Reference__c | Text | Shipper contract ref |
| Status__c | Picklist | Requested / Scheduled / Delivered / Cancelled |

---

### 2.26 Well__c

**Label:** Well  
**Description:** Oil and gas wells with lifecycle status tracking from permitted through drilling, producing, to abandonment.

| Field | Type | Description |
|---|---|---|
| Name | Text (80) | Well name |
| Account__c | Lookup(Account) | Operator account |
| Lease__c | Lookup(Lease__c) | Related lease |
| API_Number__c | Text (20) | API well number (unique) |
| Well_Type__c | Picklist | Oil / Gas / Injection / Water Disposal |
| Status__c | Picklist | Permitted / Drilling / Producing / Shut-In / Suspended / Plugged / Abandoned / Cancelled |
| Production_Status__c | Picklist | Declining / Stable / Increasing |
| Total_Depth__c | Number(10,2) | Total well depth (ft) |
| True_Vertical_Depth__c | Number(10,2) | True vertical depth (ft) |
| Spud_Date__c | Date | Drilling start date |
| Completion_Date__c | Date | Well completion date |
| Formation__c | Text | Producing formation |
| Status_Change_Date__c | Date | Last status change date |
| Last_Production_Date__c | Date | Most recent production date |
| Regulatory_District__c | Text | Regulatory district |
| Is_Declining__c | Checkbox | Production declining flag |
| Total_Oil_Volume_12M__c | Formula | Total oil last 12 months (from allocations) |
| TestViaAPI__c | Checkbox | Test flag for API validation |

---

### 2.27 Well_Operation__c

**Label:** Well Operation  
**Description:** Well lifecycle events and operations (drilling, completion, workover, P&A).

| Field | Type | Description |
|---|---|---|
| Name | Auto-number | Operation reference |
| Well__c | Lookup(Well__c) | Related well |
| Operation_Type__c | Picklist | Drilling / Completion / Workover / Plug & Abandon / Status Change |
| Start_Date__c | Date | Operation start |
| End_Date__c | Date | Operation end |
| Operation_Date__c | Date | Date of operation (for status changes) |
| Rig_Contractor__c | Text | Drilling rig contractor |
| AFE_Number__c | Text | Authorization for expenditure number |
| AFE_Amount__c | Currency | Budgeted amount |
| Actual_Cost__c | Currency | Actual cost |
| Description__c | Long Text Area | Operation description |
| Daily_Report__c | Long Text Area | Daily drilling report |
| Performed_By__c | Lookup(User) | User who performed operation |
| Status__c | Picklist | Planned / In Progress / Completed / Cancelled |

---

## 3. Enhanced Standard Objects

### 3.1 Account

**Record Types:** Operator, Partner/JV, Supplier/Vendor, Regulatory Agency, Retail Customer, Commercial Customer

| Field | Type | Description |
|---|---|---|
| EIN__c | Text | Employer Identification Number |
| DUNS__c | Text | DUNS number |
| NAICS_Code__c | Text | NAICS industry code |
| Supplier_Tier__c | Picklist | Tier 1 / Tier 2 / Tier 3 |
| Insurance_Expiration__c | Date | Insurance certificate expiry |
| HSE_Rating__c | Picklist | A / B / C / D / F |

### 3.2 Asset

**Record Types:** Pump, Compressor, Valve, Tank, Meter, Separator, Heater Treater, Generator

| Field | Type | Description |
|---|---|---|
| API_Equipment_Type__c | Text | API equipment classification |
| Criticality_Rating__c | Picklist | Low / Medium / High / Critical |
| Installation_Date__c | Date | Date installed |
| Last_Inspection_Date__c | Date | Most recent inspection |
| Inspection_Frequency_Days__c | Number | Days between inspections |
| Operating_Hours__c | Number | Total operating hours |

### 3.3 Case

**Record Types:** HSE Incident, Equipment Failure, Regulatory, Customer Issue, Field Request

| Field | Type | Description |
|---|---|---|
| Severity__c | Picklist | Low / Medium / High / Critical |
| Location__c | Text | Incident/issue location |
| Regulatory_Reportable__c | Checkbox | Reportable to regulator? |
| Well__c | Lookup(Well__c) | Related well |
| Pipeline__c | Lookup(Pipeline__c) | Related pipeline |
| Root_Cause_Category__c | Picklist | Equipment / Process / Human / External |

### 3.4 Contact

**Record Types:** Engineer, Landman, HSE Officer, Field Tech, Account Manager, Regulatory Contact

| Field | Type | Description |
|---|---|---|
| Job_Title_Oil_Gas__c | Text | O&G-specific title |
| Field_Location__c | Text | Assigned field location |
| Safety_Certifications__c | Text | Safety certs (H2S, etc.) |
| TWIC_Expiration__c | Date | Transportation Worker ID expiry |
| Emergency_Contact__c | Checkbox | Emergency contact flag |

### 3.5 Opportunity

**Record Types:** Service Sale, Equipment Sale, Supply Contract, JV Proposal

| Field | Type | Description |
|---|---|---|
| Contract_Value__c | Currency | Expected contract value |
| Start_Date__c | Date | Expected start date |
| Commodity_Type__c | Picklist | Crude / Gas / NGL / Refined |
| Volume_MMBTU__c | Number(18,2) | Volume in MMBTU |

### 3.6 WorkOrder

**Record Types:** Preventive Maintenance, Corrective, Inspection, Field Service

| Field | Type | Description |
|---|---|---|
| Well__c | Lookup(Well__c) | Related well |
| Pump__c | Text | Related pump |
| Pipeline_Station__c | Lookup(Pipeline_Station__c) | Related station |
| Permit_to_Work__c | Lookup(Permit_to_Work__c) | Safety permit |
| Isolation_Required__c | Checkbox | Energy isolation needed? |
| Lockout_Tagout__c | Checkbox | LOTO required? |

---

## 4. Object Relationship Architecture

```
Account (Operator)
├── Lease__c (1+)
│   ├── Well__c (1+) ——— Well_Operation__c (1+)
│   │   └── Production_Allocation__c (1+)
│   │       └── (references Lease__c for WI/NRI)
│   ├── Land_Parcel__c (1+) ——— (referenced by Lease__c)
│   └── Joint_Venture__c (1+)
│
├── Pipeline__c (1+)
│   ├── Pipeline_Station__c (1+)
│   │   └── Measurement__c (1+)
│   ├── Transportation_Nomination__c (1+)
│   ├── Inspection__c (1+)
│   └── HSE_Incident__c / HSE_Observation__c
│
├── Terminal__c (1+)
│   ├── Fuel_Inventory__c (1+)
│   │   └── Inventory_Transaction__c (1+)
│   ├── Measurement__c (1+)
│   └── Inspection__c
│
├── Refinery__c (1+)
│   └── Permit_to_Work__c
│
├── Retail_Outlet__c (1+)
│   └── Fuel_Inventory__c
│
├── Supply_Agreement__c (1+)
├── Service_Contract__c (1+)
├── Regulatory_Permit__c (1+)
│   └── Compliance_Report__c (1+)
├── Inspection__c (1+)
├── HSE_Incident__c
├── HSE_Observation__c
├── Permit_to_Work__c
└── Invoice__c

Cross-Object Lookups:
- HSE_Incident__c → Well__c, Pipeline__c, Retail_Outlet__c, Account__c
- Inspection__c → Pipeline__c, Well__c, Terminal__c
- Measurement__c → Pipeline__c, Pipeline_Station__c, Terminal__c
- Permit_to_Work__c → Well__c, Pipeline_Station__c, Terminal__c, Refinery__c
- Regulatory_Permit__c → Well__c, Pipeline__c, Refinery__c, Account__c
```

---

## 5. Apex Classes

### 5.1 Core Domain Services

| Class | Description | Key Methods |
|---|---|---|
| **ProductionAllocationService** | Allocates oil/gas/water volumes to wells, calculates revenue shares, enforces WI ≤ 100% | `calculateMonthlyAllocation(wellId, periodStart, periodEnd)`, `getAllocatedRevenue(allocationId)`, `validateWorkingInterest(allocations)`, `getProductionHistory(wellId, months)` |
| **HSEIncidentService** | Classifies severity, determines regulatory reportability, notifies compliance teams, escalates critical | `classifySeverity(incidentId)`, `classifySeverities(incidentIds)`, `isRegulatoryReportable(incidentId)`, `notifyComplianceTeam(incidentId)`, `notifyComplianceTeams(incidentIds)`, `escalateIfCritical(incidentId)`, `getHSEIncidents(recordId)` |
| **ComplianceDueDateService** | Tracks permit renewals, overdue reports, sends reminders | `getUpcomingRenewals(daysAhead)`, `getOverdueReports()`, `getUpcomingDeadlines(accountId)`, `updateComplianceStatuses(expiringPermitIds, statusChangedPermitIds)`, `sendRenewalReminders()` |
| **PipelineIntegrityService** | Monitors inspection compliance, flags non-compliant pipelines | `getOverdueInspections()`, `isInspectionCompliant(pipelineId)`, `flagNonCompliantPipelines()`, `calculateNextInspectionDueDate(pipelineId)` |
| **WellStatusService** | Manages well lifecycle state machine with valid transitions | `transitionWellStatus(wellId, newStatus)`, `isValidTransition(currentStatus, newStatus)`, `createWellOperations(wells)`, `getWellsDueForAbandonment()`, `getWellProduction(wellId)` |
| **InventoryBalanceService** | Tracks fuel inventory movements and reconciliations | _(methods for inventory balance tracking)_ |
| **RoyaltyCalculationService** | Calculates royalty payments from production data | _(methods for royalty calculation)_ |
| **PermitToWorkValidationService** | Validates PTW safety requirements (isolation, gas test, authorization chain) | `validateIsolationRequirements(permitId)`, `validateGasTestResults(permitId)`, `validateAuthorizationChain(permitId)`, `getPermitsToWork(parentId)`, `updatePermitStatus(permitId, newStatus)`, `getMissingRequirements(permitId)` |
| **InspectionService** | Manages inspection scheduling and compliance | _(inspection management methods)_ |

### 5.2 External API Integration Services

| Class | Description | Key Methods |
|---|---|---|
| **CommodityPricingService** | Fetches real-time commodity prices via external API | `syncPrices(agreementIds)`, `fetchPrice(apiCode)` |
| **SlackAlertService** | Sends HSE alerts to Slack via webhook | `sendAlert(recordIds)`, `sendAlertAsync(...)` |
| **SCADAIngestionAPI** | REST endpoint for SCADA pipeline measurements | `ingest()` (POST /api/scada/measurements) |
| **SCADAMeasurementProcessor** | Processes SCADA readings for anomaly detection | _(processing logic for pressure/flow anomalies)_ |
| **PetrelWellSync** | Syncs well data from Petrel/EDM system | `execute(schedulableContext)` |
| **RegulatoryFilingService** | Auto-files compliance reports to EPA CDX | _(EPA filing integration)_ |
| **EIAPricingService** | Fetches EIA energy pricing data | _(EIA API integration)_ |
| **GTMService** | Google Tag Manager integration | _(GTM tag deployment)_ |
| **GA4AdminService** | Google Analytics 4 admin operations | _(GA4 property management)_ |
| **GTMPixelBuilder** | Builds marketing pixels (LinkedIn, TikTok, Snapchat) | _(pixel code generation)_ |
| **GAEventsController** | Serves GA4 events to LWCs | _(AuraEnabled methods for LWC consumption)_ |
| **StoreController** | Store management Apex controller | _(store CRUD operations)_ |
| **ProvisioningService** | Store provisioning business logic | _(store setup automation)_ |

### 5.3 Batch & Queueable Classes

| Class | Type | Description |
|---|---|---|
| **PipelineIntegrityBatch** | Batch | Batch-updates pipeline compliance status |
| **WellProductionRollupBatch** | Batch | Rolls up production volumes to Well__c |
| **CommodityPriceSyncQueueable** | Queueable | Async commodity price sync |
| **EIAQueueable** | Queueable | Async EIA data fetch |
| **PetrelWellSyncQueueable** | Queueable | Async Petrel well sync |
| **ProvisioningQueueable** | Queueable | Async store provisioning |
| **RenewalReminderQueueable** | Queueable | Async permit renewal reminders |
| **SlackAlertQueueable** | Queueable | Async Slack alert sending |

### 5.4 Schedulers

| Class | Description | Schedule |
|---|---|---|
| **CommodityPriceSyncScheduler** | Schedules daily commodity price sync | Daily 06:00 |
| **EIAPriceSyncScheduler** | Schedules EIA price data refresh | Weekly Thu 14:30 |

### 5.5 Test Classes

| Class | Tests |
|---|---|
| **TestWellLifecycle** | Well status transitions, WellOperation creation |
| **TestHSEServices** | HSE severity classification, regulatory reporting |
| **TestFieldServices** | PTW validation, inspection services |
| **TestCommercialServices** | Production allocation, royalty calculation |
| **TestAPIEndToEnd** | End-to-end API integration tests |
| **TestEIAPricingService** | EIA pricing service tests |
| **PetrelWellSyncTest** | Petrel sync test |
| **RegulatoryFilingServiceTest** | Regulatory filing tests |

---

## 6. Triggers

| Trigger | Object | Events | Purpose |
|---|---|---|---|
| **WellTrigger** | Well__c | Before Insert, Before Update, After Insert, After Update | Defaults status to 'Permitted' on insert; validates state machine transitions on update; creates Well_Operation__c audit records |
| **HSEIncidentTrigger** | HSE_Incident__c | After Insert, After Update | Classifies severity via HSEIncidentService; determines regulatory reportability; triggers escalation for critical incidents |
| **AssetTrigger** | Asset | After Insert, After Update | Manages asset lifecycle and inspection scheduling |
| **RegulatoryPermitTrigger** | Regulatory_Permit__c | Before Update | Updates Compliance_Status__c based on expiration date proximity and status changes |
| **ProductionAllocationTrigger** | Production_Allocation__c | Before Insert | Validates working interest does not exceed 100% for overlapping periods |
| **InspectionTrigger** | Inspection__c | After Insert, After Update | Updates Pipeline__c.Last_Inspection_Date__c; calculates Next_Due_Date__c |
| **MeasurementTrigger** | Measurement__c | After Insert | Detects pressure anomalies and creates HSE_Observation__c for unsafe readings |
| **SlackAlertEventTrigger** | Platform Event | After Insert | Processes Slack alert platform events and sends notifications |

---

## 7. LWC Components

### 7.1 wellProductionChart

**Purpose:** Interactive chart showing well production trends (oil, gas, water over time).  
**Target Object:** Well__c  
**API:** `@api recordId` — Well record Id  
**SOQL:** `Production_Allocation__c WHERE Well__c = :recordId ORDER BY Period_End__c DESC`  
**Apex:** `WellStatusService.getWellProduction(wellId)` or `ProductionAllocationService.getProductionHistory(wellId, months)`

### 7.2 hseIncidentMap

**Purpose:** GIS map showing HSE incidents by location with severity color-coding.  
**Target Object:** Account, Well__c, Pipeline__c  
**API:** `@api recordId`  
**SOQL:** `HSE_Incident__c WHERE Well__c = :recordId OR Pipeline__c = :recordId OR Account__c = :recordId`  
**Apex:** `HSEIncidentService.getHSEIncidents(recordId)`

### 7.3 complianceCalendar

**Purpose:** Visual calendar of upcoming regulatory deadlines and permit renewals.  
**Target Object:** Account  
**API:** `@api recordId`  
**SOQL:** `Regulatory_Permit__c WHERE Account__c = :recordId ORDER BY Expiration_Date__c ASC`  
**Apex:** `ComplianceDueDateService.getUpcomingDeadlines(accountId)`

### 7.4 inventoryTankGauge

**Purpose:** Visual tank level indicator for terminal and retail fuel inventory.  
**Target Object:** Terminal__c  
**API:** `@api recordId`  
**SOQL:** `Fuel_Inventory__c WHERE Terminal__c = :recordId`

### 7.5 permitToWorkBoard

**Purpose:** Kanban board for PTW lifecycle (Requested → Issued → Active → Completed).  
**Target Object:** Well__c, Pipeline_Station__c, Terminal__c, Refinery__c  
**API:** `@api recordId`  
**SOQL:** `Permit_to_Work__c WHERE Well__c = :recordId OR Pipeline_Station__c = :recordId OR Terminal__c = :recordId OR Refinery__c = :recordId`  
**Apex:** `PermitToWorkValidationService.getPermitsToWork(parentId)`, `updatePermitStatus(permitId, newStatus)`

### 7.6 fieldServiceChecklist

**Purpose:** Mobile-ready inspection/PTW checklist component for field technicians.  
**Target Object:** Well__c, Terminal__c, Account__c  
**API:** `@api recordId`

### 7.7 productionAllocationReport

**Purpose:** Revenue/volume allocation report by working interest.  
**Target Object:** Well__c  
**API:** `@api recordId`  
**SOQL:** `Production_Allocation__c WHERE Well__c = :recordId ORDER BY Period_End__c DESC`

### 7.8 storeManager (Store Ecosystem — Not Part of Powershot)

**Purpose:** Store management interface for retail operations.  
**Target Object:** Store__c  
**Note:** Part of Store ecosystem — excluded from O&G powershot scope.

### 7.9 storeProvisioning (Store Ecosystem — Not Part of Powershot)

**Purpose:** Store provisioning workflow component.  
**Target Object:** Store__c  
**Note:** Part of Store ecosystem — excluded from O&G powershot scope.

### 7.10 marketDataHome

**Purpose:** Experience Cloud home-page widget showing commodity spot prices, supply agreement pricing with variance analysis, and EIA national inventory data.  
**Target:** `lightning__HomePage` (Experience Cloud + Lightning)  
**Apex:** `MarketDataController.getMarketData()` (spot prices + EIA stocks), `MarketDataController.getSupplyAgreementPricing()` (commodity-grouped supply agreements with variance)  
**Features:** CSS bar chart, price tiles, EIA inventory table, Supply Agreement Pricing section with variance badges (JS-side sort by variance descending)

---

## 8. Flows

| Flow | Trigger Type | Object | Description |
|---|---|---|---|
| **HSE_Incident_Escalation** | Record-Triggered (Create & Update) | HSE_Incident__c | Routes by severity: creates Tasks for fatalities (High), regulatory (High), and general (Normal) notifications |
| **Compliance_Calendar** | Scheduled (Daily) | Regulatory_Permit__c, Compliance_Report__c | Checks upcoming permit expirations and report due dates, sends reminders |
| **Inspection_Due** | Scheduled (Weekly) | Inspection__c | Creates Inspection records for overdue/scheduled inspections |
| **Permit_to_Work_Approval** | Record-Triggered | Permit_to_Work__c | Routes PTW for approval based on type and risk level |
| **Field_Service_Dispatch** | Record-Triggered | WorkOrder | Assigns crew, checks PTW requirements, dispatches field service |
| **Production_Reconciliation** | Scheduled (Monthly) | Production_Allocation__c | Aggregates production data, flags discrepancies |
| **Retail_Inventory_Alert** | Scheduled (Daily) | Fuel_Inventory__c | Alerts when fuel inventory is below minimum threshold |
| **HSE_Critical_Slack_Alert** | Record-Triggered (Update) | HSE_Incident__c | Sends Slack alert when severity changes to Critical (calls SlackAlertService) |
| **Joint_Venture_Billing** | Scheduled (Monthly) | Invoice__c, Joint_Venture__c | Generates JV billing invoices |
| **Land_Lease_Expiration** | Scheduled (Daily) | Lease__c | Checks for upcoming lease expirations |
| **Regulatory_Permit_Compliance** | Scheduled (Daily) | Regulatory_Permit__c | Updates compliance statuses on permits |

---

## 9. Permission Sets

| Permission Set | Access |
|---|---|
| **O_G_All_Access** | Full CRUD on all O&G objects — admin access |
| **O_G_Landman** | CRUD on Lease, Land_Parcel, Joint_Venture; read on Well |
| **O_G_Drilling_Engineer** | CRUD on Well, Well_Operation; read on Lease |
| **O_G_Production_Engineer** | CRUD on Well (production fields), Production_Allocation |
| **O_G_Pipeline_Engineer** | CRUD on Pipeline, Pipeline_Station, Measurement, Inspection |
| **O_G_Terminal_Operator** | CRUD on Terminal, Fuel_Inventory, Measurement |
| **O_G_Refinery_Manager** | CRUD on Refinery, Supply_Agreement; read on Pipeline/Terminal |
| **O_G_Retail_Manager** | CRUD on Retail_Outlet, Fuel_Inventory |
| **O_G_HSE_Advisor** | CRUD on HSE_Incident, HSE_Observation, Permit_to_Work |
| **O_G_Compliance_Analyst** | CRUD on Regulatory_Permit, Compliance_Report; read on HSE_Incident |
| **O_G_Field_Technician** | CRUD on Inspection, PTW (limited); read on Well, Pipeline, Asset |
| **O_G_Supply_Chain** | CRUD on Service_Contract, Fuel_Inventory, Inventory_Transaction |
| **O_G_Executive** | Read all O&G objects, reports, and dashboards |
| **Energy_Tab_Visibility** | Tab visibility for all O&G custom object tabs |
| **Experience_Profile_Manager** | Experience Cloud profile/portal management |
| **GTM_GA_principles_permission** | GTM/GA4 integration access |
| **GTM_Integration_Admin** | GTM admin access |
| **sfdcInternalInt__sfdc_scrt2** | Internal Salesforce security configuration |

---

## 10. External Credentials & Named Credentials

**Protocol:** All use `Basic` authentication protocol (v66.0 requirement).

| External Credential | Named Credential | Target URL | Purpose |
|---|---|---|---|
| CommodityPricing | CommodityPricing | `https://api.oilpriceapi.com/v1` | Commodity pricing web service |
| EIA_API | EIA_API | `https://api.eia.gov/v2` | US Energy Information Administration data |
| EPA_CDX_API | EPA_CDX_API | `https://cdx.epa.gov/api` | EPA Central Data Exchange for regulatory filing |
| GTM_API | GTM_API | `https://tagmanager.googleapis.com` | Google Tag Manager API |
| GTM_API | GTM_TagManager | `https://www.googletagmanager.com` | GTM container deployment |
| GTM_API | GA4_Admin | `https://analyticsadmin.googleapis.com` | Google Analytics 4 admin API |
| PetrelAPI | PetrelAPI | `https://petrel-api.company.com` | Petrel/EDM well data integration |
| Slack_HSE_Webhook | Slack_HSE_Webhook | `https://hooks.slack.com/services/T.../B.../xxxxx` | Slack HSE alert webhook |

---

## 11. Flexipages (Record Pages)

| Flexipage | Target Object | LWC Components |
|---|---|---|
| **Well_Record_Page** | Well__c | wellProductionChart, hseIncidentMap, permitToWorkBoard, fieldServiceChecklist, productionAllocationReport |
| **Pipeline_Record_Page** | Pipeline__c | hseIncidentMap, fieldServiceChecklist |
| **HSE_Incident_Record_Page** | HSE_Incident__c | _(none — no matching LWCs)_ |
| **Regulatory_Permit_Record_Page** | Regulatory_Permit__c | _(none — no matching LWCs)_ |
| **Lease_Record_Page** | Lease__c | _(none — no matching LWCs)_ |
| **Production_Allocation_Record_Page** | Production_Allocation__c | _(none — no matching LWCs)_ |
| **Account_Record_Page** | Account | complianceCalendar, fieldServiceChecklist, hseIncidentMap |
| **Terminal_Record_Page** | Terminal__c | inventoryTankGauge, fieldServiceChecklist, permitToWorkBoard |

---

## 12. Layouts

25 page layouts — one per custom object:

| Layout | Object |
|---|---|
| Well Layout | Well__c |
| Well Operation Layout | Well_Operation__c |
| Lease Layout | Lease__c |
| Land Parcel Layout | Land_Parcel__c |
| Production Allocation Layout | Production_Allocation__c |
| Pipeline Layout | Pipeline__c |
| Pipeline Station Layout | Pipeline_Station__c |
| Terminal Layout | Terminal__c |
| Measurement Layout | Measurement__c |
| Transportation Nomination Layout | Transportation_Nomination__c |
| Refinery Layout | Refinery__c |
| Retail Outlet Layout | Retail_Outlet__c |
| Supply Agreement Layout | Supply_Agreement__c |
| Fuel Inventory Layout | Fuel_Inventory__c |
| Inventory Transaction Layout | Inventory_Transaction__c |
| HSE Incident Layout | HSE_Incident__c |
| HSE Observation Layout | HSE_Observation__c |
| Permit to Work Layout | Permit_to_Work__c |
| Regulatory Permit Layout | Regulatory_Permit__c |
| Compliance Report Layout | Compliance_Report__c |
| Inspection Layout | Inspection__c |
| Joint Venture Layout | Joint_Venture__c |
| Service Contract Layout | Service_Contract__c |
| Invoice Layout | Invoice__c |
| Store Layout | Store__c |

---

## 13. Integrations & APIs

| Integration | Direction | Protocol | Purpose |
|---|---|---|---|
| **Commodity Pricing API** | Outbound | REST (JSON) | Real-time oil/gas/NGL pricing from oilpriceapi.com |
| **EIA API** | Outbound | REST (JSON) | US Energy Information Administration data |
| **SCADA / PI System** (OSIsoft) | Inbound | REST (JSON) via Apex REST endpoint | Real-time pipeline pressure/flow/temperature data |
| **EPA CDX** | Outbound | REST (JSON) | Regulatory compliance filing |
| **Petrel / EDM** | Outbound | REST (JSON) | Well data sync from drilling database |
| **Slack Webhook** | Outbound | REST (JSON) | HSE critical incident alerts |
| **Google Tag Manager** | Outbound | REST (JSON) | Marketing tag management |
| **Google Analytics 4** | Outbound | REST (JSON) | Analytics property management |
| **LinkedIn/TikTok/Snapchat** | Outbound | REST | Marketing pixel management |

---

## 14. Security Model

### Role Hierarchy

```
CEO
├── VP Upstream
│   ├── Land Manager → Landman
│   ├── Drilling Manager → Drilling Engineer
│   └── Production Manager → Production Engineer
├── VP Midstream
│   ├── Pipeline Director → Pipeline Engineer
│   └── Terminals Manager → Terminal Operator
├── VP Downstream
│   ├── Refinery Manager
│   ├── Supply & Trading Manager
│   └── Retail Operations Manager → Store Supervisor
├── VP HSE & Regulatory
│   ├── HSE Director → HSE Advisor
│   └── Regulatory Compliance Manager → Compliance Analyst
├── VP Supply Chain
│   ├── Procurement Manager
│   └── Warehouse / Inventory Manager
└── VP JV & Partnerships
```

### Sharing Model

- All custom objects: **ReadWrite** sharing model
- Well__c: **ReadWrite** with Private external sharing
- Store__c: **ReadWrite** with Private external sharing

---

## 15. Key Business Processes

| Process | Flow |
|---|---|
| **Lease Acquisition** | Prospect → Land_Parcel → Lease__c → Acquisition Cost → Well Planning |
| **Well Lifecycle** | Permitted → Drilling → Producing → Shut-In → Suspended → Plugged → Abandoned |
| **Production Accounting** | Monthly volumes → Allocation → Revenue Distribution → Royalty Payment |
| **HSE Incident** | Report → Classify → Investigate → Corrective Action → Close → Regulatory Report |
| **Permit to Work** | Request → Risk Assessment → Isolation/Test → Approve → Execute → Close |
| **Pipeline Integrity** | Schedule Inspection → Execute → Evaluate → Remediate → Re-inspect |
| **Fuel Distribution** | Refinery → Pipeline/Terminal → Retail Outlet → End Customer |
| **Compliance Cycle** | Permit → Conditions → Monitoring → Report → Renew |

---

## 16. Deployment Commands

```bash
# Deploy all metadata to main org
sf project deploy start -d "force-app\main\default" -o "ouil gas"

# Deploy specific metadata type
sf project deploy start -d "force-app\main\default\classes" -o "ouil gas"
sf project deploy start -d "force-app\main\default\lwc" -o "ouil gas"
sf project deploy start -d "force-app\main\default\objects" -o "ouil gas"
sf project deploy start -d "force-app\main\default\flows" -o "ouil gas"
sf project deploy start -d "force-app\main\default\triggers" -o "ouil gas"
sf project deploy start -d "force-app\main\default\flexipages" -o "ouil gas"
sf project deploy start -d "force-app\main\default\permissionsets" -o "ouil gas"
sf project deploy start -d "force-app\main\default\layouts" -o "ouil gas"

# Deploy to working org (oil-gas_project)
sf project deploy start -d "force-app\main\default\flexipages" -o "oil-gas_project"

# Run tests
sf apex run test -o "ouil gas" --test-level RunLocalTests -w 10

# Deploy destructive changes
sf project deploy start -o "ouil gas" --pre-destructive-changes destructiveChangesPre.xml -x package.xml -w 10

# Retrieve full metadata
sf project retrieve start -o "ouil gas" -m "CustomObject:A,Layout,Flow,ApexClass,PermissionSet"
```
