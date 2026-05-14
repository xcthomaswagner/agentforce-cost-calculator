global with sharing class XC_AFCC_AgentforceCaseLookupV2Action {
    @InvocableMethod(
        label='Look Up Case Status by Number'
        description='Finds a Salesforce Case by case number and returns support status details for Agentforce customer conversations.'
    )
    global static List<XC_AFCC_AgentforceCaseLookupResponse> lookupCases(List<XC_AFCC_AgentforceCaseLookupRequest> requests) {
        Set<String> caseNumbers = new Set<String>();
        for (XC_AFCC_AgentforceCaseLookupRequest request : requests) {
            if (request != null && !String.isBlank(request.caseNumber)) {
                caseNumbers.add(request.caseNumber.trim());
            }
        }

        Map<String, Case> casesByNumber = new Map<String, Case>();
        if (!caseNumbers.isEmpty()) {
            for (Case c : [
                SELECT CaseNumber, Subject, Status, Priority, Account.Name, Contact.Name, Contact.Email
                FROM Case
                WHERE CaseNumber IN :caseNumbers
                LIMIT 200
            ]) {
                casesByNumber.put(c.CaseNumber, c);
            }
        }

        List<XC_AFCC_AgentforceCaseLookupResponse> responses = new List<XC_AFCC_AgentforceCaseLookupResponse>();
        for (XC_AFCC_AgentforceCaseLookupRequest request : requests) {
            String requestedNumber = request == null || String.isBlank(request.caseNumber) ? null : request.caseNumber.trim();
            Case c = requestedNumber == null ? null : casesByNumber.get(requestedNumber);
            XC_AFCC_AgentforceCaseLookupResponse response = new XC_AFCC_AgentforceCaseLookupResponse();
            response.caseNumber = requestedNumber;
            response.found = c != null;
            if (c == null) {
                response.nextStep = 'Ask the customer to confirm the case number or provide their email address so support can locate the case.';
                response.summary = 'No case was found for the provided case number.';
            } else {
                response.subject = c.Subject;
                response.status = c.Status;
                response.priority = c.Priority;
                response.accountName = c.Account == null ? null : c.Account.Name;
                response.contactName = c.Contact == null ? null : c.Contact.Name;
                response.contactEmail = c.Contact == null ? null : c.Contact.Email;
                response.nextStep = determineNextStep(c);
                response.summary = 'Case ' + c.CaseNumber + ' is ' + c.Status + ' with ' + c.Priority + ' priority: ' + c.Subject + '.';
            }
            responses.add(response);
        }
        return responses;
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
