Integer caseCount = __CASE_COUNT__;
String runKey = '__RUN_KEY__';
String subjectPrefix = 'AFCC Prod-Like ' + runKey + ' Case ';
Database.DMLOptions dmlOptions = new Database.DMLOptions();
dmlOptions.DuplicateRuleHeader.allowSave = true;

List<Account> accounts = new List<Account>();
for (Integer i = 1; i <= caseCount; i++) {
    String suffix = String.valueOf(i).leftPad(3, '0');
    accounts.add(new Account(
        Name = 'AFCC Prod-Like Account ' + suffix + ' ' + runKey,
        Type = Math.mod(i, 5) == 0 ? 'Customer - Direct' : 'Prospect',
        Industry = Math.mod(i, 3) == 0 ? 'Technology' : (Math.mod(i, 3) == 1 ? 'Retail' : 'Financial Services')
    ));
}
Database.insert(accounts, dmlOptions);

List<Contact> contacts = new List<Contact>();
for (Integer i = 0; i < accounts.size(); i++) {
    String suffix = String.valueOf(i + 1).leftPad(3, '0');
    contacts.add(new Contact(
        AccountId = accounts[i].Id,
        FirstName = 'AFCC',
        LastName = 'Contact ' + suffix,
        Email = 'afcc+' + runKey.replaceAll('[^a-zA-Z0-9]', '') + '+' + suffix + '@example.invalid'
    ));
}
Database.insert(contacts, dmlOptions);

List<Case> cases = new List<Case>();
List<String> topics = new List<String>{'Billing question', 'Login issue', 'Order status', 'Return request', 'Subscription change', 'Technical troubleshooting'};
List<String> priorities = new List<String>{'Low', 'Medium', 'High'};
for (Integer i = 0; i < contacts.size(); i++) {
    String suffix = String.valueOf(i + 1).leftPad(3, '0');
    cases.add(new Case(
        AccountId = accounts[i].Id,
        ContactId = contacts[i].Id,
        Subject = subjectPrefix + suffix + ' - ' + topics[Math.mod(i, topics.size())],
        Origin = 'Web',
        Status = 'New',
        Priority = priorities[Math.mod(i, priorities.size())],
        SuppliedName = contacts[i].FirstName + ' ' + contacts[i].LastName,
        SuppliedEmail = contacts[i].Email
    ));
}
insert cases;

Map<String, Object> result = new Map<String, Object>();
result.put('runKey', runKey);
result.put('accountsCreated', accounts.size());
result.put('contactsCreated', contacts.size());
result.put('casesCreated', cases.size());
result.put('caseSubjectPrefix', subjectPrefix);
System.debug(JSON.serializePretty(result));
