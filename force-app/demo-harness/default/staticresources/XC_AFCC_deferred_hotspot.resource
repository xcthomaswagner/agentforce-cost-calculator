{
  "seed": 12345,
  "billingModel": "FLEX_CREDITS",
  "caseCount": 150,
  "accountCount": 30,
  "contactCount": 90,
  "agentCount": 4,
  "queueNames": [
    "Billing Support",
    "Order Support",
    "Returns",
    "Product Help",
    "Account Support"
  ],
  "hotspotQueue": "Billing Support",
  "dateRangeDays": 21,
  "creditRate": 0.005,
  "conversationRate": 2.0,
  "deferredRate": 0.35,
  "escalatedRate": 0.15,
  "abandonedRate": 0.05,
  "resolvedRate": 0.45,
  "unallocatedUsageRate": 0.08,
  "ledgerRowsPerCase": 5,
  "expectedResults": {
    "minimumCases": 150,
    "minimumDeferredCases": 52,
    "minimumLedgerRows": 750,
    "topQueue": "Billing Support",
    "minimumUnallocatedUsagePercent": 7.0,
    "maximumUnallocatedUsagePercent": 9.0
  },
  "scenarioName": "deferred-hotspot"
}
