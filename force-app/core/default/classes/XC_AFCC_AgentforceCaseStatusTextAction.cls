global with sharing class XC_AFCC_AgentforceCaseStatusTextAction {
    @InvocableMethod(
        label='Look Up Case Status Text'
        description='Finds a Salesforce Case by case number and returns a plain text status summary for Agentforce customer conversations.'
    )
    global static List<String> lookupCaseStatus(List<String> caseNumbers) {
        Set<String> normalizedCaseNumbers = new Set<String>();
        for (String caseNumber : caseNumbers) {
            if (!String.isBlank(caseNumber)) {
                normalizedCaseNumbers.add(caseNumber.trim());
            }
        }

        Map<String, Case> casesByNumber = new Map<String, Case>();
        if (!normalizedCaseNumbers.isEmpty()) {
            for (Case c : [
                SELECT CaseNumber, Subject, Status, Priority, Account.Name, Contact.Name, Contact.Email
                FROM Case
                WHERE CaseNumber IN :normalizedCaseNumbers
                LIMIT 200
            ]) {
                casesByNumber.put(c.CaseNumber, c);
            }
        }

        List<String> summaries = new List<String>();
        for (String caseNumber : caseNumbers) {
            String requestedNumber = String.isBlank(caseNumber) ? null : caseNumber.trim();
            Case c = requestedNumber == null ? null : casesByNumber.get(requestedNumber);
            if (c == null) {
                summaries.add('No case was found for case number ' + requestedNumber + '. Ask the customer to confirm the case number.');
            } else {
                summaries.add(
                    'Case ' + c.CaseNumber +
                    ' status: ' + c.Status +
                    '; priority: ' + c.Priority +
                    '; account: ' + safeValue(c.Account == null ? null : c.Account.Name) +
                    '; contact: ' + safeValue(c.Contact == null ? null : c.Contact.Name) +
                    '; contact email: ' + safeValue(c.Contact == null ? null : c.Contact.Email) +
                    '; subject: ' + safeValue(c.Subject) +
                    '; next step: ' + determineNextStep(c)
                );
            }
        }
        return summaries;
    }

    private static String safeValue(String value) {
        return String.isBlank(value) ? 'Not available' : value;
    }

    private static String determineNextStep(Case c) {
        String status = String.isBlank(c.Status) ? '' : c.Status.toLowerCase();
        if (status == 'closed') {
            return 'Confirm whether the customer still needs help. If yes, offer to reopen or create a follow-up case.';
        }
        if (status.contains('escalat')) {
            return 'Tell the customer the case is escalated and the support team should continue investigation with priority handling.';
        }
        if (status.contains('waiting') || status.contains('pending')) {
            return 'Tell the customer support is waiting on the next required input or internal review before the case can move forward.';
        }
        return 'Tell the customer the support team should review the case details and provide the next update.';
    }
}
