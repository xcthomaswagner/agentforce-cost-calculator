# Salesforce Metadata Spec

## 1. Naming Convention

All Salesforce custom metadata must use the `XC_AFCC` prefix.

Examples:

- `XC_AFCC_Cost_Ledger__c`
- `XC_AFCC_CostCalculationService`
- `xcAfccCostDashboard`
- `XC_AFCC_Admin`

---

## 2. Core Custom Objects

### 2.1 `XC_AFCC_Cost_Ledger__c`

Purpose: final normalized analytical cost ledger.

Recommended fields:

| Field API Name | Type | Notes |
|---|---|---|
| `XC_AFCC_Org_Id__c` | Text(18) | Salesforce org ID |
| `XC_AFCC_Billing_Model__c` | Picklist | FLEX_CREDITS, CONVERSATIONS, UNKNOWN |
| `XC_AFCC_Source_System__c` | Picklist | CSV_IMPORT, SYNTHETIC, LIVE, MANUAL |
| `XC_AFCC_Source_Record_Id__c` | Text(255), External ID | source usage ID or deterministic hash |
| `XC_AFCC_Source_Staging_Record__c` | Lookup | lookup to `XC_AFCC_Usage_Staging__c` |
| `XC_AFCC_Case__c` | Lookup(Case) | linked case |
| `XC_AFCC_Case_Number__c` | Text(30) | copied for reporting |
| `XC_AFCC_Conversation_Id__c` | Text(255) | external conversation/session ID |
| `XC_AFCC_Messaging_Session_Id__c` | Text(255) | optional |
| `XC_AFCC_Agent_Id__c` | Text(255) | optional |
| `XC_AFCC_Agent_Name__c` | Text(255) | agent display name |
| `XC_AFCC_Agent_Version__c` | Text(100) | optional |
| `XC_AFCC_Action_Id__c` | Text(255) | optional |
| `XC_AFCC_Action_Name__c` | Text(255) | action label |
| `XC_AFCC_Topic__c` | Text(255) | business topic |
| `XC_AFCC_Channel__c` | Picklist | Web, Chat, Email, Voice, Messaging, Other |
| `XC_AFCC_Queue_Name__c` | Text(255) | queue/group label |
| `XC_AFCC_Account_Id__c` | Text(18) | optional account ID copy |
| `XC_AFCC_Contact_Id__c` | Text(18) | optional contact ID copy |
| `XC_AFCC_Case_Owner_Id__c` | Text(18) | optional owner ID copy |
| `XC_AFCC_Case_Status__c` | Text(80) | copied status |
| `XC_AFCC_Case_Outcome__c` | Picklist | RESOLVED, DEFERRED, ESCALATED, ABANDONED, UNKNOWN |
| `XC_AFCC_Usage_Timestamp__c` | DateTime | usage timestamp |
| `XC_AFCC_Usage_Date__c` | Date | denormalized date |
| `XC_AFCC_Credits_Used__c` | Number(18,4) | Flex Credits |
| `XC_AFCC_Conversations_Used__c` | Number(18,4) | conversation pricing |
| `XC_AFCC_Action_Count__c` | Number(18,0) | optional |
| `XC_AFCC_Contract_Credit_Rate__c` | Currency(18,8) | rate used |
| `XC_AFCC_Contract_Conversation_Rate__c` | Currency(18,8) | rate used |
| `XC_AFCC_Allocated_Cost__c` | Currency(18,6) | calculated cost |
| `XC_AFCC_Allocation_Method__c` | Picklist | PRIMARY_CASE, EVEN_SPLIT, IMPORTED, NONE |
| `XC_AFCC_Confidence_Level__c` | Picklist | HIGH, MEDIUM, LOW |
| `XC_AFCC_Calculation_Basis__c` | Picklist | ACTUAL, IMPORTED, SYNTHETIC, ESTIMATED, ALLOCATED, INCOMPLETE |
| `XC_AFCC_Data_Set_Type__c` | Picklist | SYNTHETIC, IMPORTED, LIVE |
| `XC_AFCC_Demo_Scenario_Id__c` | Text(100) | synthetic only |
| `XC_AFCC_Raw_Payload__c` | Long Text Area | JSON/raw detail |
| `XC_AFCC_Deterministic_Key__c` | Text(255), External ID | duplicate prevention |

---

### 2.2 `XC_AFCC_Usage_Staging__c`

Purpose: raw imported/synthetic usage before normalization.

Fields:

| Field API Name | Type |
|---|---|
| `XC_AFCC_Import_Run__c` | Lookup(`XC_AFCC_Import_Run__c`) |
| `XC_AFCC_Source_System__c` | Picklist |
| `XC_AFCC_Source_Record_Id__c` | Text(255), External ID |
| `XC_AFCC_Billing_Model__c` | Picklist |
| `XC_AFCC_Usage_Timestamp__c` | DateTime |
| `XC_AFCC_Case_Id_Text__c` | Text(18) |
| `XC_AFCC_Case_Number__c` | Text(30) |
| `XC_AFCC_Conversation_Id__c` | Text(255) |
| `XC_AFCC_Messaging_Session_Id__c` | Text(255) |
| `XC_AFCC_Agent_Name__c` | Text(255) |
| `XC_AFCC_Agent_Version__c` | Text(100) |
| `XC_AFCC_Action_Name__c` | Text(255) |
| `XC_AFCC_Topic__c` | Text(255) |
| `XC_AFCC_Channel__c` | Text(80) |
| `XC_AFCC_Queue_Name__c` | Text(255) |
| `XC_AFCC_Credits_Used__c` | Number(18,4) |
| `XC_AFCC_Conversations_Used__c` | Number(18,4) |
| `XC_AFCC_Action_Count__c` | Number(18,0) |
| `XC_AFCC_Case_Outcome__c` | Picklist |
| `XC_AFCC_Data_Set_Type__c` | Picklist |
| `XC_AFCC_Processing_Status__c` | Picklist: PENDING, PROCESSED, FAILED, SKIPPED |
| `XC_AFCC_Processing_Error__c` | Long Text Area |
| `XC_AFCC_Raw_Payload__c` | Long Text Area |

---

### 2.3 `XC_AFCC_Case_Conversation_Link__c`

Purpose: associate usage/conversation IDs to Salesforce cases.

Fields:

| Field API Name | Type |
|---|---|
| `XC_AFCC_Case__c` | Lookup(Case) |
| `XC_AFCC_Case_Number__c` | Text(30) |
| `XC_AFCC_Conversation_Id__c` | Text(255) |
| `XC_AFCC_Messaging_Session_Id__c` | Text(255) |
| `XC_AFCC_Link_Method__c` | Picklist: DIRECT, IMPORTED, SYNTHETIC, INFERRED |
| `XC_AFCC_Confidence_Level__c` | Picklist: HIGH, MEDIUM, LOW |
| `XC_AFCC_Data_Set_Type__c` | Picklist |
| `XC_AFCC_Demo_Scenario_Id__c` | Text(100) |

---

### 2.4 `XC_AFCC_Org_Config__c`

Purpose: configuration for the installed org.

Fields:

| Field API Name | Type |
|---|---|
| `XC_AFCC_Org_Id__c` | Text(18) |
| `XC_AFCC_Org_Name__c` | Text(255) |
| `XC_AFCC_Is_Sandbox__c` | Checkbox |
| `XC_AFCC_Install_Mode__c` | Picklist: DEV, DEMO, TEST, SANDBOX, PRODUCTION |
| `XC_AFCC_Billing_Model__c` | Picklist: FLEX_CREDITS, CONVERSATIONS, UNKNOWN |
| `XC_AFCC_Contract_Credit_Rate__c` | Currency(18,8) |
| `XC_AFCC_Contract_Conversation_Rate__c` | Currency(18,8) |
| `XC_AFCC_Default_Credit_Rate__c` | Currency(18,8) |
| `XC_AFCC_Default_Conversation_Rate__c` | Currency(18,8) |
| `XC_AFCC_Allocation_Method__c` | Picklist |
| `XC_AFCC_Csv_Import_Enabled__c` | Checkbox |
| `XC_AFCC_Demo_Override_Enabled__c` | Checkbox |
| `XC_AFCC_Demo_Override_Expires_On__c` | Date |
| `XC_AFCC_Demo_Override_Reason__c` | Long Text Area |

---

### 2.5 `XC_AFCC_Import_Run__c`

Tracks imports.

Fields:
- `XC_AFCC_File_Name__c`
- `XC_AFCC_Import_Type__c`
- `XC_AFCC_Row_Count__c`
- `XC_AFCC_Success_Count__c`
- `XC_AFCC_Error_Count__c`
- `XC_AFCC_Status__c`
- `XC_AFCC_Started_At__c`
- `XC_AFCC_Completed_At__c`
- `XC_AFCC_Error_Message__c`

---

### 2.6 `XC_AFCC_Data_Health_Check__c`

Stores health results.

Fields:
- `XC_AFCC_Check_Name__c`
- `XC_AFCC_Status__c`
- `XC_AFCC_Detail__c`
- `XC_AFCC_Record_Count__c`
- `XC_AFCC_Warning_Level__c`
- `XC_AFCC_Run_Timestamp__c`
- `XC_AFCC_Data_Set_Type__c`

---

### 2.7 `XC_AFCC_Audit_Log__c`

Stores sensitive admin activity.

Fields:
- `XC_AFCC_Action__c`
- `XC_AFCC_User__c`
- `XC_AFCC_Timestamp__c`
- `XC_AFCC_Old_Value__c`
- `XC_AFCC_New_Value__c`
- `XC_AFCC_Environment_Mode__c`
- `XC_AFCC_Detail__c`

---

## 3. Core Apex Classes

### `XC_AFCC_EnvironmentService`

- reads Organization metadata
- returns org ID, org name, sandbox flag, org type, instance
- used by setup and guardrails

### `XC_AFCC_CostCalculationService`

- calculates Flex Credit cost
- calculates Conversation cost
- applies default rates when needed
- marks calculation basis

### `XC_AFCC_CsvImportService`

- validates CSV
- creates import run
- creates staging rows
- records failures

### `XC_AFCC_CostLedgerService`

- normalizes staging to ledger
- links cases
- calculates cost
- upserts ledger rows

### `XC_AFCC_DataHealthService`

- runs checks
- stores data health results
- produces readiness summaries

### `XC_AFCC_ReportQueryService`

- grouped reporting by allowed dimensions
- no free-form SOQL from user input
- allowlisted dimensions and metrics

### `XC_AFCC_CaseCostExplainService`

- explains one Case cost
- lists contributing ledger rows
- displays calculation basis and allocation method

---

## 4. Demo Harness Apex Classes

### `XC_AFCC_DemoGuardService`

Refuses execution unless environment/permission/override checks pass.

### `XC_AFCC_DemoScenarioService`

Loads scenario JSON and validates scenario contracts.

### `XC_AFCC_SyntheticDataFactory`

Creates deterministic Accounts, Contacts, Cases, links, staging rows, and ledger rows.

### `XC_AFCC_DemoSeeder`

Orchestrates scenario seeding.

### `XC_AFCC_DemoResetService`

Deletes only synthetic records.

### `XC_AFCC_DemoReadinessService`

Validates the expected scenario outcome.

---

## 5. LWC Components

### Core

- `xcAfccSetupWizard`
- `xcAfccDataHealth`
- `xcAfccCostDashboard`
- `xcAfccGroupedReport`
- `xcAfccCaseExplorer`
- `xcAfccCsvImporter`
- `xcAfccAdminSettings`

### Demo Harness

- `xcAfccDemoLauncher`
- `xcAfccSyntheticDataGenerator`
- `xcAfccDemoScenarioPicker`

---

## 6. Permission Sets and Custom Permissions

### Core Permission Sets

- `XC_AFCC_Admin`
- `XC_AFCC_Viewer`
- `XC_AFCC_Data_Loader`

### Demo Harness Permission Set

- `XC_AFCC_Internal_Demo_Admin`

### Demo Harness Custom Permission

- `XC_AFCC_Access_Demo_Harness`

All demo LWCs and Apex methods must check the custom permission.
