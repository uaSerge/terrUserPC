/*
 * Created by Serhii on 02.11.2018.
 */
public class AccountChangeHandler {
    public static void accountChangeAfterUpdate(List<Account> newTriggerAccs, Map<Id, Account> oldTriggerMapAccs) {
        List <Id> terIdNew = getTerritoriesList(newTriggerAccs);
        List <Id> terIdOld = getTerritoriesList(oldTriggerMapAccs.values());
        terIdNew.addAll(getTerritoriesListChild(terIdNew));
        terIdNew.addAll(getTerritoriesListParent(terIdNew));
        terIdNew.addAll(getTerritoriesListParent(terIdNew));
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
        changeAccountShare(newTriggerAccs, terrUsersNew, terrUsersOld, terIdNew);
        changeContactShare(terIdNew, terrUsersNew, terrUsersOld);
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

    public static void accountChangeAfterInsert(List<Account> newTriggerAccs) {
        List <Id> terIdNew = getTerritoriesList(newTriggerAccs);
        terIdNew.addAll(getTerritoriesListChild(terIdNew));
        terIdNew.addAll(getTerritoriesListParent(terIdNew));
        terIdNew.addAll(getTerritoriesListParent(terIdNew));
        List<TerrUser__c> terrUsersNew = [
                SELECT Territory_User__c, Territory__c
                FROM TerrUser__c
                WHERE Territory__c IN : terIdNew
        ];
        changeAccountShare(newTriggerAccs, terrUsersNew, new Map<Id, TerrUser__c>(), terIdNew);
        changeContactShare(terIdNew, terrUsersNew, new Map<Id, TerrUser__c>());
    }

//    public static void accountChangeOnAfterDel(Map<Id, Account> oldTriggerMapAccs) {
//        List <Id> terIdOld = getTerritoriesList(oldTriggerMapAccs.values());
//        terIdOld.addAll(getTerritoriesListChild(terIdOld));
//        terIdOld.addAll(getTerritoriesListParent(terIdOld));
//        terIdOld.addAll(getTerritoriesListParent(terIdOld));
//        Map<Id, TerrUser__c> terrUsersOld = new Map<Id, TerrUser__c>([
//                SELECT Territory_User__c, Territory__c
//                FROM TerrUser__c
//                WHERE Territory__c IN : terIdOld
//        ]);
//        changeAccountShare(oldTriggerMapAccs.values(), new List<TerrUser__c>(), terrUsersOld, terIdOld);
//        changeContactShare(terIdOld, new List<TerrUser__c>(), terrUsersOld);
//    }

    private static void changeAccountShare(List<Account> accountList,
                                           List<TerrUser__c> newTerrUsers,
                                           Map<Id, TerrUser__c> oldMapTerrUser,
                                           List <Id> terIdNew) {
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
            id newUser = terUser.Territory_User__c;
            Map <Id, List<Territory__c>> mapUsersWithTeritories = getMapUsersWithTeritories(newTerrUsers, terIdNew);
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

    //    private static Map <Id, List<Territory__c>> getMapUsersWithTeritories(List < TerrUser__c > newTerrUser,
    //                                                                          List <Id> terID) {
    //        Map <Id, List<Territory__c>> getMapUsersWithTer = new Map<Id, List<Territory__c>>();
    //        Map <Id, Territory__c> terWithChildTerritories = new Map<Id, Territory__c>([
    //                SELECT Name,Territory_level__c, (SELECT Name,Territory_level__c FROM Territory__r)
    //                FROM Territory__c
    //                WHERE Id IN : terID
    //        ]);
    //        List <Territory__c> territoryChildren = new List<Territory__c>();
    //        for (Territory__c ter : terWithChildTerritories.values()) {
    //            territoryChildren.addAll(ter.Territory__r);
    //        }
    //        List <Id> terIDChildren = new List<Id>();
    //        for (Territory__c t : territoryChildren) {
    //            terIDChildren.add(t.Id);
    //        }
    //        Map <Id, Territory__c> terWithParentTerritories2level = new Map<Id, Territory__c>([
    //                SELECT Name,Territory_level__c, (SELECT Name,Territory_level__c FROM Territory__r)
    //                FROM Territory__c
    //                WHERE Id IN : terIDChildren
    //        ]);
    //
    //        for (TerrUser__c user : newTerrUser) {
    //            for (Territory__c ter : terWithChildTerritories.values()) {
    //                System.debug('getMapUsersWithTer.get(user.Id) ' + getMapUsersWithTer.get(user.Id));
    //                if (getMapUsersWithTer.get(user.Id) == null) {
    //                    getMapUsersWithTer.put(user.Id, ter.Territory__r);
    //                } else getMapUsersWithTer.get(user.Id).add(ter);
    //            }
    //        }
    //        for (TerrUser__c user : newTerrUser) {
    //            for (Territory__c ter : terWithParentTerritories2level.values()) {
    //                System.debug('getMapUsersWithTer.get(user.Id) ' + getMapUsersWithTer.get(user.Id));
    //                if (getMapUsersWithTer.get(user.Id) == null) {
    //                    getMapUsersWithTer.put(user.Id, ter.Territory__r);
    //                } else getMapUsersWithTer.get(user.Id).add(ter);
    //
    //            }
    //        }
    //        return getMapUsersWithTer;
    //    }

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

    private static void changeContactShare(List <Id> terID,
                                           List<TerrUser__c> newTerrUsers,
                                           Map<Id, TerrUser__c> oldMapTerrUser) {
        List<ContactShare> contactShareListNew = new List<ContactShare>();
        //    if (newTerrUsers.size() > 0) {
        List <Reference__c> referenceList = [
                SELECT Name, Account__c, Contact__c, Account__r.Territory__c
                FROM Reference__c
                WHERE Account__r.Territory__c in : terID
        ];
        //   }else List <Reference__c> referenceList = [];
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