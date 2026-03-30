import { LightningElement, wire, track } from 'lwc';
import getRandomTip from '@salesforce/apex/CopadoTipController.getRandomTip';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

export default class CopadoTipBanner extends LightningElement {
    @track tipDescription;
    @track tipCount;
    @track tipId;
    @track tipCategory;
    @track tipStartTime;
    @track tipEndTime;
    @track tipDefault;
    @track tipUrl;
    channelName = '/event/Copado_Tip_Event__e';
    subscription = {};

    connectedCallback() {
        // Subscribe to the Platform Event channel
        this.registerEmpHandlers();
    }

    registerEmpHandlers() {
        // Register error listener
        onError(error => {
            console.error('EMP error', JSON.stringify(error));
        });

        // Register event listener
        subscribe(this.channelName, -1, this.handleEvent).then(response => {
            console.log('Subscribed to channel:', JSON.stringify(response));
            this.subscription = response;
        });
    }

    handleEvent = (message) => {
        // Check if message is defined and not null
        if (message) {
            // Check if message.data and message.data.payload are defined and not null
            if (message.data && message.data.payload) {
                const tipId = message.data.payload.Copado_Tip_ID__c;
                const startTime = message.data.payload.Default_Start_Time__c;
                const endTime = message.data.payload.Default_End_Time__c;
    
                // Log the DefaultStartTime and DefaultEndTime
                console.log('DefaultStartTime:', startTime);
                console.log('DefaultEndTime:', endTime);
    
                // Ensure both start time and end time are valid dates
                if (tipId && startTime instanceof Date && endTime instanceof Date) {
                    const currentTime = new Date();
    
                    // Check if the current time is within the range of Default Start Time and Default End Time
                    if (currentTime >= startTime && currentTime <= endTime) {
                        // Update the Copado Tip record's Default Tip field to true
                        this.updateDefaultTipStatus(tipId, true);
                    } else {
                        // Update the Copado Tip record's Default Tip field to false
                        this.updateDefaultTipStatus(tipId, false);
    
                        // Reset DefaultStartTime and DefaultEndTime
                        this.tipStartTime = null;
                        this.tipEndTime = null;
                    }
                }
            } else {
                console.error('Payload or its properties are undefined or null');
            }
        } else {
            console.error('Message is undefined');
        }
    }
    
    
    
    

    updateDefaultTipStatus(tipId, isDefault) {
        // Call Apex method to update the Copado Tip record
        updateTipDefaultStatus({ tipId: tipId, isDefault: isDefault })
            .then(result => {
                console.log('Default Tip status updated successfully:', result);
            })
            .catch(error => {
                console.error('Error updating Default Tip status:', error);
            });
    }

    disconnectedCallback() {
        // Unsubscribe from the Platform Event channel
        unsubscribe(this.subscription, response => {
            console.log('Unsubscribed from channel:', JSON.stringify(response));
        });
    }

    @wire(getRandomTip)
    wiredTips({ error, data }) {
        if (data) {
            this.tipDescription = data.TipDescription__c;
            this.tipCount = data.TipCount__c;
            this.tipId = data.Id;
            this.tipCategory = data.TipCategory__c;
            this.tipUrl = "https://boot-spare8-1.lightning.force.com/" + this.tipId;
            this.tipStartTime = data.DefaultStartTime__c;
            this.tipEndTime = data.DefaultEndTime__c;
            this.tipDefault = data.DefaultTip__c;
        } else if (error) {
            console.error('Error fetching Copado Tip of the Day:', error);
        }

    }
    
}