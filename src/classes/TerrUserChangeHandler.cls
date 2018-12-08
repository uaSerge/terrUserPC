/*
 * Created by Serhii on 31.10.2018.
 */
public class TerrUserChangeHandler {
    public static void TerrUserAfterUpdate(List<TerrUser__c> newTerrUser, Map<Id, TerrUser__c> oldMapTerrUser) {
        List <Id> terID = getTerritoriesList(oldMapTerrUser.values());
        terID.addAll(getTerritoriesListChild(terID));
        changeAccountShare(terID, newTerrUser, oldMapTerrUser);
        changeContactShare(terID, newTerrUser, oldMapTerrUser);
    }

    public static void TerrUserAfterInsert(List < TerrUser__c > newTerrUser) {
        System.debug('newTerrUser = ' + newTerrUser[0]);
        List <Id> terID = getTerritoriesList(newTerrUser);
        terID.addAll(getTerritoriesListChild(terID));
        changeAccountShare(terID, newTerrUser, new Map<Id, TerrUser__c>());
        changeContactShare(terID, newTerrUser, new Map<Id, TerrUser__c>());
    }

    public static void TerrUserOnAfterDel(Map<Id, TerrUser__c> oldMapTerrUser) {
        List <Id> terID = getTerritoriesList(oldMapTerrUser.values());
        terID.addAll(getTerritoriesListChild(terID));
        changeAccountShare(terID, new List<TerrUser__c>(), oldMapTerrUser);
        changeContactShare(terID, new List<TerrUser__c>(), oldMapTerrUser);
    }

    public static void noTwoTerrUserWithOneUser(List<TerrUser__c> newTerrUser) {
        List <TerrUser__c> usersAll = [
                SELECT Territory__c, Territory_User__c
                FROM TerrUser__c
        ];
        List <Id> terID = getTerritoriesList(newTerrUser);
        List <Id> terIDNew = getTerritoriesListChild(terID);
        List <Id> terIDParent = getTerritoriesListParent(terID);
        terIDNew.addAll(terIDParent);
        Map <Id, TerrUser__c> usersWithChildTer = new Map<Id, TerrUser__c>([
                SELECT Territory__c, Territory_User__c,Name
                FROM TerrUser__c
                WHERE Territory__r.Id IN :terIDNew
        ]);
        for (TerrUser__c user : usersAll) {
            for (TerrUser__c newUser : newTerrUser) {
                if (validTerrUser(user, newUser)
                )
                {
                    throw new SObjectException('You couldn\'t have TWO same users on one territory');
                }
                for (TerrUser__c userOld : usersWithChildTer.values()) {
                    if ((newUser.Territory_User__c == userOld.Territory_User__c) &&
                            (newUser.Territory_User__c != null)) {
                        throw new SObjectException('You couldn\'t have TWO same users on one territory');
                    }
                }
            }
        }
    }

    private static void changeContactShare(List <Id> terID,
                                           List<TerrUser__c> newTerrUsers,
                                           Map<Id, TerrUser__c> oldMapTerrUser) {
        List<ContactShare> contactShareListNew = new List<ContactShare>();

        List <Reference__c> referenceList = [
                SELECT Name, Account__c, Contact__c,Account__r.Territory__c
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
        Map <Id, List<Territory__c>> mapUsersWithTeritories = getMapUsersWithTeritories(newTerrUsers, terID);
        for (TerrUser__c terUser : newTerrUsers) {
            if ((oldMapTerrUser.size() == 0) ||
                    (terUser.Territory_User__c != oldMapTerrUser.get(terUser.Id).Territory_User__c)
            ) {
                id newUser = terUser.Territory_User__c;
                if (newUser != null) {
                    for (Contact cont : contactList) {
                        Boolean canShare = false;
                        for (Reference__c ref : referenceList) {
                            if (ref.Contact__c == cont.Id) {
                                canShare = (terUser.Territory__c == ref.Account__r.Territory__c ||
                                        checkOtherTeritories(mapUsersWithTeritories, terUser,
                                                ref.Account__r.Territory__c));
                            }
                        }
                        if (canShare) {
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
        Map <Id, List<Territory__c>> mapUsersWithTeritories = getMapUsersWithTeritories(newTerrUsers, terID);
        for (TerrUser__c terUser : newTerrUsers) {
            if ((oldMapTerrUser.size() == 0) ||
                    (terUser.Territory_User__c != oldMapTerrUser.get(terUser.Id).Territory_User__c)) {
                id newUser = terUser.Territory_User__c;
                if (newUser != null) {
                    for (Account acc : accountList) {
                        if (terUser.Territory__c == acc.Territory__c ||
                                checkOtherTeritories(mapUsersWithTeritories, terUser, acc.Territory__c)) {
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
        }
        if (oldMapTerrUser.size() > 0) {
            delete oldAccountShareList;
        }
        List <Database.SaveResult> sres = Database.insert(accountShareListNew, false);
        validationSave(sres);
    }

    private static Boolean checkOtherTeritories(Map <Id, List<Territory__c>> mapUsersWithTeritories,
                                                TerrUser__c terUser,
                                                Id accountTerr) {
        List<Territory__c> territories = mapUsersWithTeritories.get(terUser.Id);
        Boolean checkDone = false;
        if (territories != null) {
            for (Territory__c ter : territories) {

                checkDone = (ter.Id == accountTerr);
                if (checkDone) break;
            }
        }
        return checkDone;
    }

    private static Map <Id, List<Territory__c>> getMapUsersWithTeritories(List < TerrUser__c > newTerrUser,
                                                                          List <Id> terID) {
        terID.addAll(getTerritoriesListChild(terID));
        Map <Id, Territory__c> terWithChildTerritories = new Map<Id, Territory__c>([
                SELECT Name,Territory_level__c, (SELECT Id,Name,Territory_level__c FROM Territory__r)
                FROM Territory__c
                WHERE Id IN : terID
        ]);
        Map <Id, List<Territory__c>> getMapUsersWithTer = new Map<Id, List<Territory__c>>();
        for (TerrUser__c user : newTerrUser) {
            if (!getMapUsersWithTer.containsKey(user.Id)) {
                getMapUsersWithTer.put(user.Id, terWithChildTerritories.get(user.Territory__c).Territory__r);
            } else getMapUsersWithTer.get(user.Id).addAll(
                    terWithChildTerritories.get(user.Territory__c).Territory__r);
        }
        getTerritoriesWihChildSecondLevel(terWithChildTerritories, getMapUsersWithTer);
        return getMapUsersWithTer;
    }

    public static void getTerritoriesWihChildSecondLevel(Map <Id, Territory__c> terWithChildTerritories,
                                                         Map <Id, List<Territory__c>> getMapUsersWithTer) {
        for (Id userId : getMapUsersWithTer.keySet()) {
            if (getMapUsersWithTer.values() != null && getMapUsersWithTer.values().size() > 0) {
                for (List <Territory__c> listTer : getMapUsersWithTer.values()) {
                    for (Territory__c ter : listTer) {
                        getMapUsersWithTer.get(userId).addAll(
                                terWithChildTerritories.get(ter.Id).Territory__r);
                    }
                }
            }
        }
    }

    private static List <Id> getTerritoriesListChild(List <id> listTerr) {
        List <Territory__c> terWithChildTerritories = [
                SELECT Name,Territory_level__c, (SELECT Name,Territory_level__c FROM Territory__r)
                FROM Territory__c
                WHERE Id IN : listTerr
        ];
        List <Territory__c> territoryChildren = new List<Territory__c>();
        for (Territory__c ter : terWithChildTerritories) {
            territoryChildren.addAll(ter.Territory__r);
        }
        List <Id> terIDChildren = new List<Id>();
        for (Territory__c t : territoryChildren) {
            terIDChildren.add(t.Id);
        }
        if (terIDChildren.size() > 0) {
            List<Id> lastListChild = getTerritoriesListChild(terIDChildren);
            terIDChildren.addAll(lastListChild);
            return terIDChildren;
        }
        return new List<Id>();
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

    private static List <Id> getTerritoriesList(List <TerrUser__c> listTerrUser) {
        List <Id> terID = new List<Id>();
        for (TerrUser__c t : listTerrUser) {
            terID.add(t.Territory__c);
            System.debug('TerrUser__c.Territory__c = ' + t.Territory__c);
        }
        System.debug('terID = ' + terID[0]);
        return terID;
    }

    private static Boolean validTerrUser(TerrUser__c user, TerrUser__c newUser) {
        return(newUser.Territory__c == user.Territory__c) && (newUser.Territory_User__c == user.Territory_User__c) &&
                (newUser.Territory_User__c != null) && (user.id != newUser.Id);
    }

    private static List <Id> getTerritoriesListParent(List <id> listTerr) {
        List <Territory__c> terWithParentTerritories = [
                SELECT Name,Territory_level__c, Parent_territory__c
                FROM Territory__c
                WHERE Id IN : listTerr
        ];
        List <Id> territoryParentId = new List<Id>();
        for (Territory__c ter : terWithParentTerritories) {
            territoryParentId.add(ter.Parent_territory__c);
        }
        return territoryParentId;
    }
}