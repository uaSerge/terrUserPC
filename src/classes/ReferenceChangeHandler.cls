/*
 * Created by Serhii on 02.11.2018.
 */
public class ReferenceChangeHandler {
public static void referenceChangeAfterUpdate(List<Reference__c> newTriggerRefs, Map<Id, Reference__c> oldTriggerMapRefs) {
    List<Account> accountListNew = getAccountListFromRefs(newTriggerRefs);
    List<Account> accountListOld = getAccountListFromRefs(oldTriggerMapRefs.values());
    List <Id> terIDNew = getTerritoriesList(accountListNew);
    List <Id> terIDOld = getTerritoriesList(accountListOld);
    List<TerrUser__c> terrUsersNew = [
            SELECT Territory_User__c, Territory__c
            FROM TerrUser__c
            WHERE Territory__c IN : terIdNew
    ];
    Map<Id, TerrUser__c> terrUsersOld = new Map<Id, TerrUser__c>([
            SELECT Territory_User__c, Territory__c
            FROM TerrUser__c
            WHERE Territory__c IN : terIdOld
    ]);
    changeContactShare(newTriggerRefs,terrUsersNew,terrUsersOld);
}

    public static void referenceChangeAfterInsert(List<Reference__c> newTriggerRefs) {
        List<Account> accountListNew = getAccountListFromRefs(newTriggerRefs);
        List <Id> terIDNew = getTerritoriesList(accountListNew);
        List<TerrUser__c> terrUsersNew = [
                SELECT Territory_User__c, Territory__c
                FROM TerrUser__c
                WHERE Territory__c IN : terIdNew
        ];
        changeContactShare(newTriggerRefs,terrUsersNew,new Map<Id, TerrUser__c>());
    }

    public static void referenceChangeOnAfterDel(Map<Id, Reference__c> oldTriggerMapRefs) {
        List<Account> accountListOld = getAccountListFromRefs(oldTriggerMapRefs.values());
        List <Id> terIDOld = getTerritoriesList(accountListOld);
        Map<Id, TerrUser__c> terrUsersOld = new Map<Id, TerrUser__c>([
                SELECT Territory_User__c, Territory__c
                FROM TerrUser__c
                WHERE Territory__c IN : terIdOld
        ]);
        changeContactShare(oldTriggerMapRefs.values(),new List<TerrUser__c>(),terrUsersOld);
    }

    private static void changeContactShare(List <Reference__c> referenceList,
                                           List<TerrUser__c> newTerrUsers,
                                           Map<Id, TerrUser__c> oldMapTerrUser) {
        List<ContactShare> contactShareListNew = new List<ContactShare>();
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
                    WHERE ContactId IN :contactList
            AND UserOrGroupId IN : userList
            AND (RowCause = :Schema.ContactShare.RowCause.Manual)
            ];
        }
        for (TerrUser__c terUser : newTerrUsers) {
            if ((oldMapTerrUser.size() == 0) || terUser.Territory_User__c == null||
                    (terUser.Territory_User__c != oldMapTerrUser.get(terUser.Id).Territory_User__c)) {
                id newUser = terUser.Territory_User__c;
                if (newUser != null) {
                    for (Contact cont : contactList) {
                        Boolean canShare = false;
                        for (Reference__c ref : referenceList) {
                            if (ref.Contact__c == cont.Id) {
                                canShare = (ref.Account__r.Territory__c==terUser.Territory__c);
                            }
                        }
                        if (canShare || (oldMapTerrUser.size() == 0)) {
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
        }
        if (oldMapTerrUser.size() > 0) {
            delete oldContactShareList;
        }
        List <Database.SaveResult> sres = Database.insert(contactShareListNew, false);
        //  validationSave(sres);
    }

    public static List<Account> getAccountListFromRefs(List<Reference__c> newTriggerRefs) {
        List <Id> accIdFromReferencesNew = new List<Id>();
        for (Reference__c ref : newTriggerRefs) {
            accIdFromReferencesNew.add(ref.Account__c);
        }
        List<Account> accountList = [
                SELECT Name, Territory__c
                FROM Account
                WHERE Id in : accIdFromReferencesNew
        ];
        return accountList;
    }

    private static List <Id> getTerritoriesList(List <Account> accountList) {
        List <Id> terID = new List<Id>();
        for (Account acc : accountList) {
            terID.add(acc.Territory__c);
            System.debug('Account.Territory__c = ' + acc.Territory__c);
        }
        System.debug('terID = ' + terID[0]);
        return terID;
    }
}