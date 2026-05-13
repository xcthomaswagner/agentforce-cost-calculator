# Native Agentforce Source Spec

## Purpose

This spec defines how Core discovers and analyzes Agentforce/Service Cloud data without relying on synthetic data or CSV import.

## Design Rules

- Use Salesforce-native data only.
- Do not add external middleware, databases, or services.
- Do not compile-time reference optional objects that may not exist in scratch orgs.
- Use dynamic describe and dynamic SOQL for optional Service Cloud/Agentforce objects.
- Materialize normalized rows into XC ledger objects only after source discovery.
- Mark native rows with `XC_AFCC_Source_System__c = LIVE`.

## Required Standard Objects

Core Step 2 expects these objects in an Agentforce-enabled Service Cloud org:

- `Account`
- `Contact`
- `Case`

## Optional Native Source Objects

Core must detect and use these when available:

- `MessagingSession`
- `AgentWork`
- `Conversation`

The first release implementation may estimate usage units from session/work records when billing-grade usage units are not available directly in the object. Those rows must remain auditable through source object name, source record id, calculation basis, and raw payload.

## Sync Output

Native sync creates:

- `XC_AFCC_Import_Run__c` with type `NATIVE_SYNC`
- `XC_AFCC_Usage_Staging__c` rows with source `LIVE`
- `XC_AFCC_Cost_Ledger__c` rows with source `LIVE`

## Case Linking

Case linking should use the strongest available reference:

1. Direct Case lookup/id field on the native source row.
2. Work item or related record id when it points to a Case.
3. Case number copied from a native field, if present.
4. No allocation, with confidence `LOW`.

## Health Checks

Data health must report:

- Service Cloud object access.
- Native source object availability.
- Native source row count.
- Live ledger row count.
- Unallocated live usage percentage.
- Estimated cost row count.

## Known Implementation Caveat

Salesforce stores some conversation content off-platform. Core should not attempt to parse off-platform transcripts through Apex. Detailed transcript analysis belongs in a future version using Salesforce-supported Conversation Data APIs or Data Cloud.
