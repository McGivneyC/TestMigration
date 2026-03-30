import { LightningElement, wire, track, api } from 'lwc';
import getTips from '@salesforce/apex/CopadoTipController.getTips';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';

export default class CopadoTips extends NavigationMixin(LightningElement) {
    @track defaultTip;
    @track randomTip;
    @track showNoTipMessage = false;
    wiredTipsResult;

    @wire(getTips)
    wiredTips(result) {
        this.wiredTipsResult = result;
        const { data, error } = result;
        if (data) {
            this.defaultTip = data.defaultTip;
            this.randomTip = data.randomTip;
            this.showNoTipMessage = !data.defaultTip && !data.randomTip;
        } else if (error) {
            this.showNoTipMessage = true;
        }
    }

    navigateToRecord(event) {
        const recordId = event.currentTarget.dataset.id;
        console.log('Navigating to record ID:', recordId);
    
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }

    refreshTips() {
        return refreshApex(this.wiredTipsResult);
    }
}