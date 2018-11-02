trigger TerritoryUniqCheckTrigger on Territory__c (before insert, before update) {
    if (Trigger.isBefore) {
        if (Trigger.isUpdate) {
            TerritoryUniqCheckHandler.uniqCheckAfterUpdateDelete(Trigger.new);
        }
        if (Trigger.isInsert) {
            TerritoryUniqCheckHandler.uniqCheckAfterUpdateDelete(Trigger.new);
        }
    }
}