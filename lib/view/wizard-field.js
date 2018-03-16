'use babel'
/** @jsx etch.dom */

const etch = require('etch');
const fieldRenderer = require('../util/field-renderer');

class WizardField {
  constructor (props, children) {
    this.props = props;

    // then call `etch.initialize`:
    etch.initialize(this)
  }

  render(){
    return fieldRenderer.render(this.props.field, this.props.items);
  }

  setValue(value){
    //TODO: custom logic here
  }

  getValue(){
    //TODO: custom logic here
  }

  update (props, children) {
    this.props = props;
    return etch.update(this)
  }

  async destroy () {
    await etch.destroy(this)
  }
}

module.exports = WizardField
