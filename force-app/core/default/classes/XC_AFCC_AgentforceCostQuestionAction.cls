global with sharing class XC_AFCC_AgentforceCostQuestionAction {
    private static final Integer TOP_LIMIT = 5;

    private class PeriodFilter {
        Date startDate;
        Date endDateExclusive;
        String label;
    }

    @InvocableMethod(
        label='Answer Cost Question'
        description='Answers supported Agentforce cost questions from Salesforce cost ledger data.'
    )
    global static List<String> answerCostQuestions(List<String> questions) {
        List<String> answers = new List<String>();
        for (String question : questions) {
            answers.add(answerOne(question));
        }
        return answers;
    }

    private static String answerOne(String question) {
        if (String.isBlank(question)) {
            return 'Ask a question about Agentforce cost, such as total cost, cost by queue, deferred case cost, unallocated usage, estimated cost, or the cost for a specific case number.';
        }

        String q = question.toLowerCase();
        PeriodFilter period = parsePeriod(q);
        String caseNumber = extractCaseNumber(question);

        if (caseNumber != null && (q.contains('cost') || q.contains('spend') || q.contains('why'))) {
            return answerCaseCost(caseNumber, period);
        }
        if (q.contains('unallocated') || q.contains('unlinked') || q.contains('not linked') || q.contains('no case')) {
            return answerUnallocated(period);
        }
        if (q.contains('estimated') || q.contains('missing rate') || q.contains('contract rate') || q.contains('default rate') || q.contains('incomplete')) {
            return answerEstimated(period);
        }
        if (q.contains('deferred')) {
            return answerDeferred(q, period);
        }
        if (q.contains('total') || q.contains('overall')) {
            return answerTotal(period);
        }

        String dimension = detectDimension(q);
        if (dimension != null) {
            return answerGrouped(dimension, period, null, null);
        }

        return answerTotal(period);
    }

    private static String answerTotal(PeriodFilter period) {
        AggregateResult total = (AggregateResult) Database.query(
            'SELECT COUNT(Id) rowCount, SUM(XC_AFCC_Allocated_Cost__c) cost, ' +
            'SUM(XC_AFCC_Credits_Used__c) credits, SUM(XC_AFCC_Conversations_Used__c) conversations ' +
            'FROM XC_AFCC_Cost_Ledger__c' + whereClause(period, null, null)
        )[0];

        Integer rows = toInteger(total.get('rowCount'));
        if (rows == 0) {
            return 'No Agentforce cost rows were found' + periodText(period) + '. Run native usage sync after conversations exist, then ask again.';
        }

        return 'Total Agentforce cost' + periodText(period) + ' is ' + money(total.get('cost')) +
            ' across ' + rows + ' cost rows, using ' + numberText(total.get('credits')) +
            ' credits and ' + numberText(total.get('conversations')) + ' conversations.';
    }

    private static String answerCaseCost(String caseNumber, PeriodFilter period) {
        Case c;
        List<Case> cases = [
            SELECT Id, CaseNumber, Subject, Status, Priority, Account.Name, Contact.Name
            FROM Case
            WHERE CaseNumber = :caseNumber
            LIMIT 1
        ];
        if (!cases.isEmpty()) {
            c = cases[0];
        }

        String extraWhere = c == null
            ? 'XC_AFCC_Case_Number__c = \'' + String.escapeSingleQuotes(caseNumber) + '\''
            : '(XC_AFCC_Case__c = \'' + String.escapeSingleQuotes(String.valueOf(c.Id)) + '\' OR XC_AFCC_Case_Number__c = \'' + String.escapeSingleQuotes(caseNumber) + '\')';

        AggregateResult total = (AggregateResult) Database.query(
            'SELECT COUNT(Id) rowCount, SUM(XC_AFCC_Allocated_Cost__c) cost, ' +
            'SUM(XC_AFCC_Credits_Used__c) credits, SUM(XC_AFCC_Conversations_Used__c) conversations ' +
            'FROM XC_AFCC_Cost_Ledger__c' + whereClause(period, extraWhere, null)
        )[0];

        Integer rows = toInteger(total.get('rowCount'));
        if (rows == 0) {
            return 'No Agentforce cost rows were found for case ' + caseNumber + periodText(period) + '.';
        }

        String answer = 'Case ' + caseNumber + ' cost' + periodText(period) + ' is ' + money(total.get('cost')) +
            ' across ' + rows + ' cost rows, using ' + numberText(total.get('credits')) +
            ' credits and ' + numberText(total.get('conversations')) + ' conversations.';
        if (c != null) {
            answer += ' Case status is ' + safe(c.Status) + ', priority is ' + safe(c.Priority) +
                ', account is ' + safe(c.Account == null ? null : c.Account.Name) +
                ', contact is ' + safe(c.Contact == null ? null : c.Contact.Name) + '.';
        }

        List<XC_AFCC_Cost_Ledger__c> rowsForCase = Database.query(
            'SELECT XC_AFCC_Agent_Name__c, XC_AFCC_Action_Name__c, XC_AFCC_Topic__c, XC_AFCC_Queue_Name__c, ' +
            'XC_AFCC_Case_Outcome__c, XC_AFCC_Allocated_Cost__c, XC_AFCC_Calculation_Basis__c, XC_AFCC_Usage_Timestamp__c ' +
            'FROM XC_AFCC_Cost_Ledger__c' + whereClause(period, extraWhere, null) +
            ' ORDER BY XC_AFCC_Allocated_Cost__c DESC NULLS LAST, XC_AFCC_Usage_Timestamp__c ASC LIMIT 3'
        );
        if (!rowsForCase.isEmpty()) {
            List<String> drivers = new List<String>();
            for (XC_AFCC_Cost_Ledger__c row : rowsForCase) {
                drivers.add(
                    safe(row.XC_AFCC_Queue_Name__c) + ' / ' +
                    safe(row.XC_AFCC_Topic__c) + ' / ' +
                    safe(row.XC_AFCC_Action_Name__c) + ': ' +
                    money(row.XC_AFCC_Allocated_Cost__c) +
                    ' (' + friendly(row.XC_AFCC_Calculation_Basis__c) + ')'
                );
            }
            answer += ' Top cost drivers: ' + String.join(drivers, '; ') + '.';
        }
        return answer;
    }

    private static String answerDeferred(String q, PeriodFilter period) {
        String dimension = detectDimension(q);
        if (dimension == null) {
            dimension = 'queue';
        }
        return answerGrouped(dimension, period, 'XC_AFCC_Case_Outcome__c = \'DEFERRED\'', 'deferred case cost');
    }

    private static String answerGrouped(String dimension, PeriodFilter period, String extraWhere, String customSubject) {
        Map<String, String> fieldsByDimension = new Map<String, String>{
            'queue' => 'XC_AFCC_Queue_Name__c',
            'agent' => 'XC_AFCC_Agent_Name__c',
            'topic' => 'XC_AFCC_Topic__c',
            'channel' => 'XC_AFCC_Channel__c',
            'outcome' => 'XC_AFCC_Case_Outcome__c',
            'date' => 'XC_AFCC_Usage_Date__c'
        };
        String fieldName = fieldsByDimension.get(dimension);
        if (fieldName == null) {
            return answerTotal(period);
        }

        String subject = customSubject == null ? 'Agentforce cost by ' + dimension : customSubject + ' by ' + dimension;
        String soql = 'SELECT ' + fieldName + ' groupValue, COUNT(Id) rowCount, COUNT_DISTINCT(XC_AFCC_Case_Number__c) caseCount, ' +
            'SUM(XC_AFCC_Allocated_Cost__c) cost, SUM(XC_AFCC_Credits_Used__c) credits, SUM(XC_AFCC_Conversations_Used__c) conversations ' +
            'FROM XC_AFCC_Cost_Ledger__c' + whereClause(period, extraWhere, fieldName + ' != null') +
            ' GROUP BY ' + fieldName + ' ORDER BY SUM(XC_AFCC_Allocated_Cost__c) DESC NULLS LAST LIMIT ' + TOP_LIMIT;

        List<String> parts = new List<String>();
        for (AggregateResult ar : Database.query(soql)) {
            String label = safe(String.valueOf(ar.get('groupValue')));
            String part = label + ': ' + money(ar.get('cost')) + ' across ' + toInteger(ar.get('rowCount')) + ' rows';
            Integer caseCount = toInteger(ar.get('caseCount'));
            if (caseCount > 0) {
                Decimal cost = toDecimal(ar.get('cost'));
                part += ', ' + caseCount + ' cases, ' + money(cost / caseCount) + ' per case';
            }
            parts.add(part);
        }

        if (parts.isEmpty()) {
            return 'No ' + subject + ' rows were found' + periodText(period) + '.';
        }
        return subject.capitalize() + periodText(period) + ': ' + String.join(parts, '; ') + '.';
    }

    private static String answerUnallocated(PeriodFilter period) {
        AggregateResult total = (AggregateResult) Database.query(
            'SELECT COUNT(Id) rowCount, SUM(XC_AFCC_Allocated_Cost__c) cost FROM XC_AFCC_Cost_Ledger__c' + whereClause(period, null, null)
        )[0];
        AggregateResult unallocated = (AggregateResult) Database.query(
            'SELECT COUNT(Id) rowCount, SUM(XC_AFCC_Allocated_Cost__c) cost FROM XC_AFCC_Cost_Ledger__c' +
            whereClause(period, 'XC_AFCC_Case__c = null AND XC_AFCC_Case_Number__c = null', null)
        )[0];
        Integer totalRows = toInteger(total.get('rowCount'));
        Integer unallocatedRows = toInteger(unallocated.get('rowCount'));
        Decimal percent = totalRows == 0 ? 0 : (Decimal.valueOf(unallocatedRows) * 100 / Decimal.valueOf(totalRows)).setScale(2);
        return 'Unallocated Agentforce usage' + periodText(period) + ' is ' + unallocatedRows + ' of ' + totalRows +
            ' cost rows (' + percent + '%), representing ' + money(unallocated.get('cost')) + ' of cost.';
    }

    private static String answerEstimated(PeriodFilter period) {
        String estimatedWhere = 'XC_AFCC_Calculation_Basis__c IN (\'ESTIMATED\', \'INCOMPLETE\')';
        AggregateResult estimated = (AggregateResult) Database.query(
            'SELECT COUNT(Id) rowCount, SUM(XC_AFCC_Allocated_Cost__c) cost, SUM(XC_AFCC_Credits_Used__c) credits, ' +
            'SUM(XC_AFCC_Conversations_Used__c) conversations FROM XC_AFCC_Cost_Ledger__c' + whereClause(period, estimatedWhere, null)
        )[0];
        Integer rows = toInteger(estimated.get('rowCount'));
        if (rows == 0) {
            return 'No estimated or incomplete Agentforce cost rows were found' + periodText(period) + '.';
        }
        return 'Estimated or incomplete Agentforce cost' + periodText(period) + ' is ' + money(estimated.get('cost')) +
            ' across ' + rows + ' rows, using ' + numberText(estimated.get('credits')) +
            ' credits and ' + numberText(estimated.get('conversations')) +
            ' conversations. Review contract rates and source linkage for these rows.';
    }

    private static String detectDimension(String q) {
        q = q.replace('agentforce', '');
        if (q.contains('queue')) return 'queue';
        if (q.contains('agent')) return 'agent';
        if (q.contains('topic')) return 'topic';
        if (q.contains('channel')) return 'channel';
        if (q.contains('outcome') || q.contains('resolution')) return 'outcome';
        if (q.contains('date') || q.contains('day') || q.contains('daily')) return 'date';
        return null;
    }

    private static PeriodFilter parsePeriod(String q) {
        PeriodFilter p = new PeriodFilter();
        Date today = Date.today();
        if (q.contains('last month')) {
            Date startOfThisMonth = Date.newInstance(today.year(), today.month(), 1);
            p.startDate = startOfThisMonth.addMonths(-1);
            p.endDateExclusive = startOfThisMonth;
            p.label = ' last month';
        } else if (q.contains('this month') || q.contains('month to date')) {
            p.startDate = Date.newInstance(today.year(), today.month(), 1);
            p.endDateExclusive = today.addDays(1);
            p.label = ' this month';
        } else if (q.contains('today')) {
            p.startDate = today;
            p.endDateExclusive = today.addDays(1);
            p.label = ' today';
        } else if (q.contains('yesterday')) {
            p.startDate = today.addDays(-1);
            p.endDateExclusive = today;
            p.label = ' yesterday';
        } else if (q.contains('last 7 days') || q.contains('past 7 days')) {
            p.startDate = today.addDays(-6);
            p.endDateExclusive = today.addDays(1);
            p.label = ' for the last 7 days';
        } else if (q.contains('last 30 days') || q.contains('past 30 days')) {
            p.startDate = today.addDays(-29);
            p.endDateExclusive = today.addDays(1);
            p.label = ' for the last 30 days';
        }
        return p;
    }

    private static String whereClause(PeriodFilter period, String extraWhere, String extraWhere2) {
        List<String> predicates = new List<String>();
        if (period != null && period.startDate != null) {
            predicates.add('XC_AFCC_Usage_Date__c >= ' + String.valueOf(period.startDate));
            predicates.add('XC_AFCC_Usage_Date__c < ' + String.valueOf(period.endDateExclusive));
        }
        if (!String.isBlank(extraWhere)) {
            predicates.add('(' + extraWhere + ')');
        }
        if (!String.isBlank(extraWhere2)) {
            predicates.add('(' + extraWhere2 + ')');
        }
        return predicates.isEmpty() ? '' : ' WHERE ' + String.join(predicates, ' AND ');
    }

    private static String extractCaseNumber(String question) {
        String normalized = question.replaceAll('[^A-Za-z0-9]+', ' ');
        for (String token : normalized.split(' ')) {
            if (token != null && token.length() >= 5 && token.length() <= 12 && token.replaceAll('[0-9]', '').length() == 0) {
                return token;
            }
        }
        return null;
    }

    private static Integer toInteger(Object value) {
        if (value == null) return 0;
        return Integer.valueOf(String.valueOf(value));
    }

    private static Decimal toDecimal(Object value) {
        if (value == null) return 0;
        return Decimal.valueOf(String.valueOf(value));
    }

    private static String money(Object value) {
        Decimal amount = toDecimal(value).setScale(2);
        return '$' + String.valueOf(amount);
    }

    private static String numberText(Object value) {
        return String.valueOf(toDecimal(value).setScale(2));
    }

    private static String periodText(PeriodFilter period) {
        return period == null || String.isBlank(period.label) ? '' : period.label;
    }

    private static String safe(String value) {
        return String.isBlank(value) || value == 'null' ? 'Not specified' : friendly(value);
    }

    private static String friendly(String value) {
        if (String.isBlank(value)) return 'Not specified';
        String cleaned = value.replace('_', ' ');
        return cleaned.equals(cleaned.toUpperCase()) ? cleaned.toLowerCase().capitalize() : cleaned;
    }
}
