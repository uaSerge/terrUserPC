/*
 * Created by Serhii on 02.11.2018.
 */
public class AccountChangeHandler {
    public static void accountChangeAfterUpdate(List<Account> newTriggerAccs, Map<Id, Account> oldTriggerMapAccs) {
        List <Id> terIdNew = getTerritoriesList(newTriggerAccs);
        List <Id> terIdOld = getTerritoriesList(oldTriggerMapAccs.values());
        List<TerrUser__c> terrUsersNew = [
                SELECT Territory_User__c
                FROM TerrUser__c
                WHERE Territory__c IN : terIdNew
        ];
        Map<Id, TerrUser__c> terrUsersOld = new Map<Id, TerrUser__c>([
                SELECT Territory_User__c
                FROM TerrUser__c
                WHERE Territory__c IN : terIdOld
        ]);
        changeAccountShare(newTriggerAccs, terrUsersNew, terrUsersOld);
        changeContactShare(terIdNew, terrUsersNew, terrUsersOld);
    }

    public static void accountChangeAfterInsert (List<Account> newTriggerAccs){
        List <Id> terIdNew = getTerritoriesList(newTriggerAccs);
        List<TerrUser__c> terrUsersNew = [
                SELECT Territory_User__c
                FROM TerrUser__c
                WHERE Territory__c IN : terIdNew
        ];
        changeAccountShare(newTriggerAccs, terrUsersNew, new Map<Id, TerrUser__c>());
        changeContactShare(terIdNew, terrUsersNew, new Map<Id, TerrUser__c>());
    }

    public static void accountChangeOnAfterDel (Map<Id, Account> oldTriggerMapAccs){
        List <Id> terIdOld = getTerritoriesList(oldTriggerMapAccs.values());
        Map<Id, TerrUser__c> terrUsersOld = new Map<Id, TerrUser__c>([
                SELECT Territory_User__c
                FROM TerrUser__c
                WHERE Territory__c IN : terIdOld
        ]);
        changeAccountShare(oldTriggerMapAccs.values(), new List<TerrUser__c>(), terrUsersOld);
        changeContactShare(terIdOld, new List<TerrUser__c>(), terrUsersOld);
    }

    private static void changeAccountShare(List<Account> accountList,
                                           List<TerrUser__c> newTerrUsers,
                                           Map<Id, TerrUser__c> oldMapTerrUser) {
        List<AccountShare> accountShareListNew = new List<AccountShare>();
        List<AccountShare> oldAccountShareList = new List<AccountShare>();
        if (oldMapTerrUser.size() > 0) {
            List<Id> userList = new List<Id>();
            for (TerrUser__c tu : oldMapTerrUser.values()) {
                userList.add(tu.Territory_User__c);
            }
            oldAccountShareList = [
                    SELECT Id, AccountId, UserOrGroupId, AccountAccessLevel
                    FROM AccountShare
                    WHERE AccountId IN :accountList AND UserOrGroupId IN : userList AND (RowCause = :Schema.AccountShare.RowCause.Manual)
            ];
        }
        for (TerrUser__c terUser : newTerrUsers) {
//            if(terUser.Territory_User__c != null) {
//                if ((oldMapTerrUser.size() == 0) ||
//                        (terUser.Territory_User__c != oldMapTerrUser.get(terUser.Id).Territory_User__c)) {
                    id newUser = terUser.Territory_User__c;
            if (newUser != null) {
                for (Account acc : accountList) {
                    if (terUser.Territory__c == acc.Territory__c) {
                        AccountShare accShare = new AccountShare();
                        accShare.AccountId = acc.id;
                        accShare.UserOrGroupId = newUser;
                        accShare.AccountAccessLevel = 'Edit';
                        accShare.OpportunityAccessLevel = 'Edit';
                        accShare.RowCause = Schema.AccountShare.RowCause.Manual;
                        accountShareListNew.add(accShare);
                    }
                }

            }
        }
        if (oldMapTerrUser.size() > 0) {
            delete oldAccountShareList;
        }
        List <Database.SaveResult> sres = Database.insert(accountShareListNew, false);
        validationSave(sres);
    }
    private static void changeContactShare(List <Id> terID,
                                           List<TerrUser__c> newTerrUsers,
                                           Map<Id, TerrUser__c> oldMapTerrUser) {
        List<ContactShare> contactShareListNew = new List<ContactShare>();
        List <Reference__c> referenceList = [
                SELECT Name, Account__c, Contact__c, Account__r.Territory__c
                FROM Reference__c
                WHERE Account__r.Territory__c in : terID
        ];
        List <Id> contactId = new List<Id>();
        for (Reference__c r : referenceList) {
            contactId.add(r.Contact__c);
            System.debug('Reference__c.Contact__c = ' + r.Contact__c);
        }
        List<Contact> contactList = [
                SELECT Name, AccountId
                FROM Contact
                WHERE id IN : contactId
        ];
        List<ContactShare> oldContactShareList = new List<ContactShare>();
        if (oldMapTerrUser.size() > 0) {
            List<Id> userList = new List<Id>();
            for (TerrUser__c tu : oldMapTerrUser.values()) {
                userList.add(tu.Territory_User__c);
            }
            oldContactShareList = [
                    SELECT Id, ContactId, UserOrGroupId, ContactAccessLevel
                    FROM ContactShare
                    WHERE ContactId IN :contactList AND UserOrGroupId IN : userList AND (RowCause = :Schema.ContactShare.RowCause.Manual)
            ];
        }
        for (TerrUser__c terUser : newTerrUsers) {
//            if ((oldMapTerrUser.size() == 0) ||
//                    (terUser.Territory_User__c != oldMapTerrUser.get(terUser.Id).Territory_User__c)) {
                id newUser = terUser.Territory_User__c;
            if (newUser != null) {
                for (Contact cont : contactList) {
                    Id territory;
                    for (Reference__c ref : referenceList) {
                        if (ref.Contact__c == cont.Id) {
                            territory = ref.Account__r.Territory__c;
                        }
                    }
                    if (territory == terUser.Territory__c) {
                        ContactShare contShare = new ContactShare();
                        contShare.ContactId = cont.id;
                        contShare.UserOrGroupId = newUser;
                        contShare.ContactAccessLevel = 'Edit';
                        contShare.RowCause = Schema.ContactShare.RowCause.Manual;
                        contactShareListNew.add(contShare);
                    }
                }
            }
        }
        if (oldMapTerrUser.size() > 0) {
            delete oldContactShareList;
        }
        List <Database.SaveResult> sres = Database.insert(contactShareListNew, false);
        validationSave(sres);
    }

    public static void validationSave(List <Database.SaveResult> sres) {
        for (Database.SaveResult sr : sres) {
            if (!sr.isSuccess()) {
                Database.Error err = sr.getErrors()[0];
                if (!(err.getStatusCode() == StatusCode.FIELD_FILTER_VALIDATION_EXCEPTION &&
                        err.getMessage().contains('AccessLevel'))) {
                    throw new DmlException ();
                }
            }
        }
    }

    private static List <Id> getTerritoriesList(List <Account> newTriggerAccs) {
        List <Id> terID = new List<Id>();
        for (Account acc : newTriggerAccs) {
            terID.add(acc.Territory__c);
            System.debug('Account.Territory__c = ' + acc.Territory__c);
        }
        System.debug('terID = ' + terID[0]);
        return terID;
    }
}