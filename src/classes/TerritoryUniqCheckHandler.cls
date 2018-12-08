/*
 * Created by Serhii on 02.11.2018.
 */
public class TerritoryUniqCheckHandler {
    public static void uniqCheckAfterUpdateDelete(List<Territory__c> newTriggerTerritories) {
        List<Id> territoryParentIdList = new List<Id>();
        Set<String> names = new Set<String>();
        for (Territory__c ter : newTriggerTerritories) {
            territoryParentIdList.add(ter.Parent_territory__c);
            names.add(ter.Name);
        }
        Map<Id, Territory__c> territoryMap = new Map<Id, Territory__c>([
                SELECT Name,Territory_level__c, Parent_territory__c
                FROM Territory__c
                WHERE Parent_territory__c IN : territoryParentIdList AND Name IN :names
        ]);
        for (Territory__c terChildOld : territoryMap.values()) {
            for (Territory__c terChildNew : newTriggerTerritories) {
                if (uniqCheckName(terChildOld, terChildNew)) {
                    terChildNew.addError('Territory with this name already exist.');
                    //                    throw new SObjectException('Territory with this name already exist.');
                }
            }
        }
    }

    public static Boolean uniqCheckName(Territory__c terChildOld, Territory__c terChildNew) {
        return terChildOld.Parent_territory__c == terChildNew.Parent_territory__c &&
                        terChildOld.Name == terChildNew.Name &&
            //          terChildOld.Territory_level__c == terChildNew.Territory_level__c &&
                        terChildOld.id != terChildNew.id;
    }
}