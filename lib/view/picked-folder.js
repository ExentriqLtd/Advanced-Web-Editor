'use babel';
'use strict';
/** @jsx etch.dom */

const etch = require('etch');

class PickedFolder {
  constructor (props, children) {
    this.props = props;
    etch.initialize(this);
  }

  render(){
    return <atom-panel class="picked-folder">
      Target folder:
      <span class='inline-block highlight'>
        {this.props.path == null ? "Select one, please" : this.props.path}
      </span>
    </atom-panel>
  }

  update (props, children) {
    this.props = props;
    return etch.update(this)
  }

  async destroy () {
    await etch.destroy(this)
  }
}

module.exports = PickedFolder
