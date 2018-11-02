/*
 * Created by Serhii on 31.10.2018.
 */
public class TerrUserChangeHandler {
    public static void TerrUserAfterUpdate(List<TerrUser__c> newTerrUser, Map<Id, TerrUser__c> oldMapTerrUser) {
        System.debug('newTerrUser = ' + newTerrUser[0]);
        List <Id> terID = getTerritoriesList(oldMapTerrUser.values());
        changeAccountShare(terID, newTerrUser, oldMapTerrUser);
        changeContactShare(terID, newTerrUser, oldMapTerrUser);

        //  List <Reference__Share> referenceListNew = new List<Reference__Share>();

    }

    private static void changeContactShare(List <Id> terID,
                                           List<TerrUser__c> newTerrUsers,
                                           Map<Id, TerrUser__c> oldMapTerrUser) {
        List<ContactShare> contactShareListNew = new List<ContactShare>();

        List <Reference__c> referenceList = [
                SELECT Name, Account__c, Contact__c
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
                    WHERE ContactId IN :contactList
            AND UserOrGroupId IN : userList
            AND (RowCause = :Schema.ContactShare.RowCause.Manual)
            ];
        }
        for (TerrUser__c terUser : newTerrUsers) {
            if ((oldMapTerrUser.size() == 0) ||
                    (terUser.Territory_User__c != oldMapTerrUser.get(terUser.Id).Territory_User__c)) {
                id newUser = terUser.Territory_User__c;
                if (newUser != null) {
                    for (Contact cont : contactList) {
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

    private static void changeAccountShare(List <Id> terID,
                                           List<TerrUser__c> newTerrUsers,
                                           Map<Id, TerrUser__c> oldMapTerrUser) {
        List<AccountShare> accountShareListNew = new List<AccountShare>();
        List<Account> accountList = [
                SELECT Name, Territory__c
                FROM Account
                WHERE Territory__c in : terID
        ];
        List<AccountShare> oldAccountShareList = new List<AccountShare>();
        if (oldMapTerrUser.size() > 0) {
            List<Id> userList = new List<Id>();
            for (TerrUser__c tu : oldMapTerrUser.values()) {
                userList.add(tu.Territory_User__c);
            }
            oldAccountShareList = [
                    SELECT Id, AccountId, UserOrGroupId, AccountAccessLevel
                    FROM AccountShare
                    WHERE AccountId IN :accountList
            AND UserOrGroupId IN : userList
            AND (RowCause = :Schema.AccountShare.RowCause.Manual)
            ];
        }
        for (TerrUser__c terUser : newTerrUsers) {
            if ((oldMapTerrUser.size() == 0) ||
                    (terUser.Territory_User__c != oldMapTerrUser.get(terUser.Id).Territory_User__c)) {
                id newUser = terUser.Territory_User__c;
                if (newUser != null) {
                    for (Account acc : accountList) {
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

    public static void TerrUserAfterInsert(List < TerrUser__c > newTerrUser) {
        System.debug('newTerrUser = ' + newTerrUser[0]);
        List <Id> terID = getTerritoriesList(newTerrUser);
        changeAccountShare(terID, newTerrUser, new Map<Id, TerrUser__c>());
        changeContactShare(terID, newTerrUser, new Map<Id, TerrUser__c>());
    }

    public static void TerrUserOnAfterDel(Map<Id, TerrUser__c> oldMapTerrUser) {
        List <Id> terID = getTerritoriesList(oldMapTerrUser.values());
        changeAccountShare(terID, new List<TerrUser__c>(), oldMapTerrUser);
        changeContactShare(terID, new List<TerrUser__c>(), oldMapTerrUser);
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

    private static List <Id> getTerritoriesList(List <TerrUser__c> oldListTerrUser) {
        List <Id> terID = new List<Id>();
        for (TerrUser__c t : oldListTerrUser) {
            terID.add(t.Territory__c);
            System.debug('TerrUser__c.Territory__c = ' + t.Territory__c);
        }
        System.debug('terID = ' + terID[0]);
        return terID;
    }

    //    private static Boolean equalAccShare(AccountShare accShare, AccountShare oldAccountShare) {
    //        return (accShare.AccountId == oldAccountShare.AccountId) &&
    //                (accShare.UserOrGroupId == oldAccountShare.UserOrGroupId) &&
    //                (accShare.AccountAccessLevel == oldAccountShare.AccountAccessLevel);
    //    }

    public static void noTwoTerrUserWithOneUser(List<TerrUser__c> newTerrUser,
                                                Map<Id, TerrUser__c> oldMapTerrUser) {
        List <TerrUser__c> usersAll = [
                SELECT Territory__c, Territory_User__c
                FROM TerrUser__c
        //                WHERE Id NOT IN :oldMapTerrUser.keySet()
        //                AND Id NOT IN :newTerrUser
        ];
        usersAll.addAll(newTerrUser);
        System.debug('validTerrUser ');
        for (TerrUser__c user : usersAll) {
            for (TerrUser__c newUser : newTerrUser) {
                if (validTerrUser(user, newUser)) {
                    System.debug('validTerrUser :' + validTerrUser(user, newUser) + '; user :' + user + ' newUser: ' +
                            newUser);
                    throw new SObjectException('You couldn\'t have TWO same users on one territory');
                }
            }
        }
    }

    private static Boolean validTerrUser(TerrUser__c user, TerrUser__c newUser) {
        return(newUser.Territory__c == user.Territory__c) && (newUser.Territory_User__c == user.Territory_User__c) &&
                (newUser.Territory_User__c != null) && (user.id != newUser.Id);
    }
}