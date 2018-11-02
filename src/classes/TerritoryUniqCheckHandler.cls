/*
 * Created by Serhii on 02.11.2018.
 */
public class TerritoryUniqCheckHandler {
    public static void uniqCheckAfterUpdateDelete(List<Territory__c> newTriggerTerritories) {
        Map<Id, Territory__c> territoryMap = new Map<Id, Territory__c>([
                SELECT Name,Territory_level__c, Parent_territory__c
                FROM Territory__c
        ]);
        for (Territory__c terChildOld : territoryMap.values()) {
            for (Territory__c terChildNew : newTriggerTerritories) {
                if (uniqCheckName(terChildOld, terChildNew)) {
                    throw new SObjectException('Territory with this name already exist.');
                }
            }
        }
    }

    public static Boolean uniqCheckName(Territory__c terChildOld, Territory__c terChildNew) {
        return terChildOld.Parent_territory__c == terChildNew.Parent_territory__c &&
                        terChildOld.Name == terChildNew.Name &&
            //            terChildOld.Territory_level__c == terChildNew.Territory_level__c &&
                        terChildOld.id != terChildNew.id;
    }
}
