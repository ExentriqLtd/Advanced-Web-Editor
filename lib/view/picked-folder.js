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
        {this.props.path == null ? "Select one, please" : this.cleanupPath()}
      </span>
    </atom-panel>
  }

  cleanupPath(){
    if(!this.props.rootPath){
      return this.props.path;
    } else {
      return this.props.path.substring(this.props.rootPath.length);
    }
  }

  update (props, children) {
    var self = this;
    Object.keys(props).forEach((k) => self.props[k] = props[k]);
    return etch.update(this)
  }

  async destroy () {
    await etch.destroy(this)
  }
}

module.exports = PickedFolder
