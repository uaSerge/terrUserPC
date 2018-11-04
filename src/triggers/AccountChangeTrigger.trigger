trigger AccountChangeTrigger on Account (after update, after insert, after delete) {
	if (Trigger.isAfter) {
		if (Trigger.isUpdate) {
			AccountChangeHandler.accountChangeAfterUpdate(Trigger.new,Trigger.oldMap);
		}
		if (Trigger.isInsert) {
			AccountChangeHandler.accountChangeAfterInsert(Trigger.new);
		}
		if (Trigger.isDelete) {
//			AccountChangeHandler.accountChangeOnAfterDel(Trigger.oldMap);
		}
	}
}