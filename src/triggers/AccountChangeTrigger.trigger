trigger AccountChangeTrigger on Account (after update, after insert) {
	if (Trigger.isAfter) {
		if (Trigger.isUpdate) {
			AccountChangeHandler.accountChangeAfterUpdate(Trigger.new,Trigger.oldMap);
		}
		if (Trigger.isInsert) {
			AccountChangeHandler.accountChangeAfterInsert(Trigger.new);
		}
	}
}