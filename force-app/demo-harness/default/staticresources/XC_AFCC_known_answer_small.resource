{
  "seed": 12345,
  "billingModel": "FLEX_CREDITS",
  "caseCount": 3,
  "accountCount": 1,
  "contactCount": 3,
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
  "deferredRate": 0.34,
  "escalatedRate": 0.33,
  "abandonedRate": 0,
  "resolvedRate": 0.33,
  "unallocatedUsageRate": 0,
  "ledgerRowsPerCase": 0,
  "expectedResults": {
    "minimumCases": 3,
    "minimumDeferredCases": 1,
    "minimumLedgerRows": 5,
    "totalCredits": 100,
    "totalCost": 0.5
  },
  "scenarioName": "known-answer-small"
}
