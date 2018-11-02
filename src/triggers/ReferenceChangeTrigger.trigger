trigger ReferenceChangeTrigger on Reference__c (after update, after insert, after delete) {
    if (Trigger.isAfter) {
        if (Trigger.isUpdate) {
            ReferenceChangeHandler.referenceChangeAfterUpdate(Trigger.new, Trigger.oldMap);
        }
        if (Trigger.isInsert) {
            ReferenceChangeHandler.referenceChangeAfterInsert(Trigger.new);
        }
        if (Trigger.isDelete) {
            ReferenceChangeHandler.referenceChangeOnAfterDel(Trigger.oldMap);
        }
    }
}