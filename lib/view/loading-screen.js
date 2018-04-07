'use babel';
'use strict';
/** @jsx etch.dom */

const etch = require('etch');

class LoadingScreen {
  constructor (props, children) {
    this.props = props;
    etch.initialize(this);
  }

  render(){
    return <atom-panel>
      <span class='loading loading-spinner-large inline-block'></span>
      <span>
        <h1>{this.props.message}</h1>
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

module.exports = LoadingScreen
