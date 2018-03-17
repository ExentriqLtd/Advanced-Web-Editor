'use babel';
'use strict';

/** @jsx etch.dom */

const etch = require('etch');
const utils = require('../util/wizard-utils');
const path = require('path');
const EventEmitter = require('events');

class DirectoryView{
  constructor (props, children) {
    var self = this;
    this.props = props;
    var init;
    this.directories = [];
    if(!props.collapsed){
      this.directories = utils.listDirectoriesSync(props.path);
    }

    this.emitter = props.emitter;

    this.emitter.on("selectedDirectory", (directory) => {
      // console.log("selectedDirectory", directory)
      var prevSel = (self.props.selected === true);
      self.props.selected = directory === self.props.path;
      if(prevSel !== self.props.selected){
        etch.update(self);
      }
    })

    etch.initialize(this);
  }

  render(){
    return <ul class={this.outerClass()}>
      <li class={this.innerClass()}>
        <div class='list-item'>
          <span class='icon icon-file-directory' on={{click:this.toggleCollapse}}></span>
          <span on={{click:this.selectDirectory}}>{this.dirName()}</span>
        </div>

        {this.renderChildren()}
      </li>
    </ul>
  }

  update (props, children) {
    this.props = props;
    return etch.update(this);
  }

  async destroy () {
    await etch.destroy(this)
  }

  toggleCollapse(e){
    this.props.collapsed = !this.props.collapsed;
    if(!this.props.collapsed){
      this.directories = utils.listDirectoriesSync(this.props.path);
    }
    etch.update(this);
  }

  selectDirectory(e){
    this.emitter.emit("selectedDirectory", this.props.path);
  }

  outerClass() {
    var baseClass = "list-tree";
    if(this.props.root){
      baseClass += " has-collapsable-children";
    }
    return baseClass;
  }

  innerClass(){
    var baseClass = "list-nested-item";
    if(this.props.collapsed){
      baseClass += " collapsed";
    }
    if(this.props.selected){
      baseClass += " selected";
    }
    return baseClass;
  }

  dirName(){
    if(this.props.root){
      return this.props.path;
    } else {
      return path.basename(this.props.path);
    }
  }


  renderChildren(){
    var self = this;

    var fullPath = function(dir){
      return path.join(self.props.path, dir);
    }

    return self.directories.map( (dir) => {
      return <DirectoryView path={fullPath(dir)} root={false} collapsed={true} emitter={self.emitter}></DirectoryView>
    })
  }
}

class DirectoryPicker {
  constructor (props, children) {
    this.props = props;
    this.emitter = new EventEmitter();

    etch.initialize(this);
  }

  render(){
    return <atom-panel>
      <DirectoryView path={this.props.path} root={true} emitter={this.emitter}></DirectoryView>
    </atom-panel>
  }

  update (props, children) {
    this.props = props;
    return etch.update(this);
  }

  async destroy () {
    await etch.destroy(this)
  }
}

module.exports = DirectoryPicker
