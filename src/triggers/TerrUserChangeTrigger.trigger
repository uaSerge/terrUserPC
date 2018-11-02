trigger TerrUserChangeTrigger on TerrUser__c (after insert, after update, after delete, before update, before insert) {
    if (Trigger.isAfter) {
        if (Trigger.isUpdate) {
            //            ActivityDataHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
            TerrUserChangeHandler.TerrUserAfterUpdate(Trigger.new,Trigger.oldMap);
        }
        if (Trigger.isInsert) {
            TerrUserChangeHandler.TerrUserAfterInsert(Trigger.new);
        }
        if (Trigger.isDelete) {
            TerrUserChangeHandler.TerrUserOnAfterDel(Trigger.oldMap);
        }
    }
    if (Trigger.isBefore) {
        if (Trigger.isUpdate){
            TerrUserChangeHandler.noTwoTerrUserWithOneUser(Trigger.new,Trigger.oldMap);
        }
        if (Trigger.isInsert){
            TerrUserChangeHandler.noTwoTerrUserWithOneUser(Trigger.new, new Map<Id, TerrUser__c> ());
        }
    }
    }