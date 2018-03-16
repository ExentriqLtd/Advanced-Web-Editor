'use babel';
'use strict';
/** @jsx etch.dom */

const etch = require('etch');

class WizardField {
  constructor (props, children) {
    this.props = props;
    this.initHelpers();
    etch.initialize(this)
  }

  initHelpers(){
    var self = this;
    this.renderers = {
      "string": self._defaultRenderer.bind(self),
      "file": self._defaultRenderer.bind(self),
      "select": self._selectRenderer.bind(self)
    };

    this.getters = {
      "string": self._defaultGetter.bind(self),
      "file": self._defaultGetter.bind(self),
      "select": self._selectGetter.bind(self)
    }

    this.setters = {
      "string": self._defaultSetter.bind(self),
      "file": self._defaultSetter.bind(self),
      "select": self._selectSetter.bind(self)
    }
  }

  _defaultRenderer(){
    return <atom-text-editor ref="field" id={this.props.field.id}
      attributes={{mini: true, tabindex: "-1"}}>
    </atom-text-editor>
  }

  _defaultGetter(){
    return this.element.component.props.model.getText();
  }

  _defaultSetter(value){
    this.element.component.props.model.setText(value);
  }

  _selectGetter(){
    return this.element.value;
  }

  _selectSetter(value){
    this.element.value = value;
  }

  _selectRenderer(){
    var self = this;
    return <select ref="field" id={this.props.field.id} attributes={{tabindex:"-1"}}>
      {this.props.items.map( (item) => <option value={item.value}>{item.display}</option>)}
    </select>
  }

  render(){
    var type = this.props.field.type;
    if(this.renderers.hasOwnProperty(type)){
      return this.renderers[type]();
    } else {
      return this._defaultRenderer();
    }
  }

  setValue(value){
    var type = this.props.field.type;
    if(this.renderers.hasOwnProperty(type)){
      return this.setters[type](value);
    } else {
      return this._defaultSetter(value);
    }
  }

  getValue(){
    var type = this.props.field.type;
    if(this.renderers.hasOwnProperty(type)){
      return this.getters[type]();
    } else {
      return this._defaultGetter();
    }
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
