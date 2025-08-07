trigger SetDefaultfromAddress on conference360__Event__c (before insert, before update) {
    for (conference360__Event__c evt : Trigger.new) {
        evt.conference360__Automated_Email_From_Address__c = 'registration@cerc.wisc.edu';
    }
}