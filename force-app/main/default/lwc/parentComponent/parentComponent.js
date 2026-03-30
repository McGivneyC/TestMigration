import { LightningElement, api, track } from 'lwc';


export default class ParentComponent extends LightningElement {
input = '';
selected = false;
list = [];
emptyList = false;

//insert the value form the Lightning input filed into the list array
 addInputToList() {
  this.list.push(this.input)
  this.input = '';
  this.emptyList = true;
  console.log(this.list)
  
 }

 handleReset() {
  this.input = '';
  this.selected = false;
  this.list = [];
  this.emptyList = false;
 }

 handleChange(event) {
  this.input = event.detail.value;
}

//should set the input var to the value of the detail key of the inputitemselect event
 handleSelect(event) {
  console.log(event, this.input)
  this.input = event.detail; 
  this.selected = true;
  
 }
}