'use babel';
'use strict';
/** @jsx etch.dom */

const etch = require('etch');

class LanguageSelect {
  constructor (props, children) {
    this.props = props;
    etch.initialize(this);
  }

  render(){
    return <select class="input-select" tabindex={this.props.tabindex}>
      <option value="en">English</option>
      <option value="ja">Japanese</option>
      <option value="ko">Korean</option>
    </select>
  }

  update (props, children) {
    var self = this;
    Object.keys(props).forEach((k) => self.props[k] = props[k]);
    return etch.update(this)
  }

  async destroy () {
    await etch.destroy(this)
  }

  getValue(){
    return this.element.value;
  }

  setValue(value){
    this.element.value = value;
  }
}

module.exports = LanguageSelect
