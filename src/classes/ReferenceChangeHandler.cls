/*
 * Created by Serhii on 02.11.2018.
 */
public class ReferenceChangeHandler {
public static void referenceChangeAfterUpdate(List<Reference__c> newTriggerRefs, Map<Id, Reference__c> oldTriggerMapRefs) {
    List<Account> accountListNew = getAccountListFromRefs(newTriggerRefs);
    List<Account> accountListOld = getAccountListFromRefs(oldTriggerMapRefs.values());
    List <Id> terIDNew = getTerritoriesList(accountListNew);
    terIdNew.addAll(getTerritoriesListChild(terIdNew));
    terIdNew.addAll(getTerritoriesListParent(terIdNew));
    terIdNew.addAll(getTerritoriesListParent(terIdNew));
    List <Id> terIDOld = getTerritoriesList(accountListOld);
    terIdOld.addAll(getTerritoriesListChild(terIdOld));
    terIdOld.addAll(getTerritoriesListParent(terIdOld));
    terIdOld.addAll(getTerritoriesListParent(terIdOld));
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
    changeContactShare(newTriggerRefs,terrUsersNew,terrUsersOld, terIDNew);
}

    public static void referenceChangeAfterInsert(List<Reference__c> newTriggerRefs) {
        List<Account> accountListNew = getAccountListFromRefs(newTriggerRefs);
        List <Id> terIDNew = getTerritoriesList(accountListNew);
        terIdNew.addAll(getTerritoriesListChild(terIdNew));
        terIdNew.addAll(getTerritoriesListParent(terIdNew));
        terIdNew.addAll(getTerritoriesListParent(terIdNew));
        List<TerrUser__c> terrUsersNew = [
                SELECT Territory_User__c, Territory__c
                FROM TerrUser__c
                WHERE Territory__c IN : terIdNew
        ];
        changeContactShare(newTriggerRefs,terrUsersNew,new Map<Id, TerrUser__c>(), terIDNew);
    }

    public static void referenceChangeOnAfterDel(Map<Id, Reference__c> oldTriggerMapRefs) {
        List<Account> accountListOld = getAccountListFromRefs(oldTriggerMapRefs.values());
        List <Id> terIDOld = getTerritoriesList(accountListOld);
        terIdOld.addAll(getTerritoriesListChild(terIdOld));
        terIdOld.addAll(getTerritoriesListParent(terIdOld));
        terIdOld.addAll(getTerritoriesListParent(terIdOld));
        Map<Id, TerrUser__c> terrUsersOld = new Map<Id, TerrUser__c>([
                SELECT Territory_User__c, Territory__c
                FROM TerrUser__c
                WHERE Territory__c IN : terIdOld
        ]);
        changeContactShare(oldTriggerMapRefs.values(),new List<TerrUser__c>(),terrUsersOld, terIdOld);
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
    private static void changeContactShare(List <Reference__c> referenceList,
                                           List<TerrUser__c> newTerrUsers,
                                           Map<Id, TerrUser__c> oldMapTerrUser, List <Id> terID) {
        List<ContactShare> contactShareListNew = new List<ContactShare>();
        if (newTerrUsers.size()>0) {
            referenceList = [
                    SELECT Name, Account__c, Contact__c, Account__r.Territory__c
                    FROM Reference__c
                    WHERE Account__r.Territory__c in : terID
            ];
        }
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
//            if ((oldMapTerrUser.size() == 0) || terUser.Territory_User__c == null||
//                    (terUser.Territory_User__c != oldMapTerrUser.get(terUser.Id).Territory_User__c)) {
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
                        if (canShare
                               // || (oldMapTerrUser.size() == 0)&& (newTerrUsers.size() > 0)
                                ) {
                            ContactShare contShare = new ContactShare();
                            contShare.ContactId = cont.id;
                            contShare.UserOrGroupId = newUser;
                            contShare.ContactAccessLevel = 'Edit';
                            contShare.RowCause = Schema.ContactShare.RowCause.Manual;
                            contactShareListNew.add(contShare);
                        }
                    }
                }
          //  }
        }
        if (oldMapTerrUser.size() > 0) {
            delete oldContactShareList;
        }
        List <Database.SaveResult> sres = Database.insert(contactShareListNew, false);
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
        Map <Id, Territory__c> terWithChildTerritories = new Map<Id, Territory__c>([
                SELECT Name,Territory_level__c, (SELECT Id,Name,Territory_level__c FROM Territory__r)
                FROM Territory__c
                WHERE Id IN : terID
        ]);
        Map <Id, Territory__c> terWithChildTerritoriesFirstLevel = new Map<Id, Territory__c>([
                SELECT Name,Territory_level__c
                FROM Territory__c
        ]);
        Map <Id, List<Territory__c>> getMapUsersWithTer = new Map<Id, List<Territory__c>>();
        for (TerrUser__c user : newTerrUser) {
            if (terWithChildTerritories.get(user.Territory__c).Territory_level__c != 1) {
                if (!getMapUsersWithTer.containsKey(user.Id)) {
                    getMapUsersWithTer.put(user.Id, terWithChildTerritories.get(user.Territory__c).Territory__r);
                } else getMapUsersWithTer.get(user.Id).addAll(
                        terWithChildTerritories.get(user.Territory__c).Territory__r);
                //     }
            } else getMapUsersWithTer.put(user.Id, terWithChildTerritoriesFirstLevel.values());
        }
        return getMapUsersWithTer;
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
        return terID;
    }
}