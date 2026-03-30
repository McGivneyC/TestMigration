import { LightningElement, api } from 'lwc';


export default class ChildComponent extends LightningElement {
@api inputItem

fireSelectEvent() {
  // this.inputItem = event.detail;
try{
    const itemselect = new CustomEvent('inputitemselect', {
        // detail contains only primitives
        detail: this.inputItem
    });
    // Fire the event from c-child-Component
    this.dispatchEvent(itemselect);

    console.log(itemselect, this.inputItem)
  }catch(error) {
    console.log(error)
  }
}

}