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
    this.childrenCount = 0;
    if(!props.collapsed){
      this.directories = utils.listDirectoriesSync(props.path);
    }

    this.emitter = props.emitter;

    this.eventHandler = (directory) => {
      // console.log("selectedDirectory", directory);
      var prevSel = (self.props.selected === true);
      self.props.selected = directory === self.props.path;
      if(prevSel !== self.props.selected){
        etch.update(self);
      }
    }

    this.subscribeSelectedEvent();
    etch.initialize(this);
  }

  render(){
    return <ul class={this.outerClass()}>
      <li class={this.innerClass()}>
        <div class='list-item'>
          <span class='dir-icon icon icon-file-directory' on={{click:this.toggleCollapse}}></span>
          <span class='dir-name' on={{click:this.selectDirectory}}>{this.dirName()}</span>
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
    // console.log("destroy " + this.props.path);
    this.unsubscribeSelectedEvent();
    await etch.destroy(this)
  }

  toggleCollapse(e){
    this.props.collapsed = !this.props.collapsed;
    if(!this.props.collapsed && this.directories.length == 0){
      this.directories = utils.listDirectoriesSync(this.props.path);
      this.subscribeChildrenToEvent()
    } else {
      this.unsubscribeChildrenToEvent();
    }
    etch.update(this);
  }

  subscribeChildrenToEvent(){
    for(var i = 0; i < this.childrenCount; i++){
      this.refs["child" + i].subscribeSelectedEvent();
    }
  }

  unsubscribeChildrenToEvent(){
    for(var i = 0; i < this.childrenCount; i++){
      this.refs["child" + i].unsubscribeSelectedEvent();
    }
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

    // console.log("children", self.childrenCount)

    var fullPath = function(dir){
      return path.join(self.props.path, dir);
    }

    self.childrenCount = self.directories.length;

    return self.directories.map( (dir, i) => {
      return <DirectoryView ref={"child" + i} path={fullPath(dir)} root={false} collapsed={true} emitter={self.emitter}></DirectoryView>
    })
  }

  subscribeSelectedEvent(){
    // console.log(this.props.path, "subscribing")
    this.emitter.on("selectedDirectory", this.eventHandler);
  }

  unsubscribeSelectedEvent(){
    // console.log(this.props.path, "unsubscribing")
    this.emitter.removeListener("selectDirectory", this.eventHandler);
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
