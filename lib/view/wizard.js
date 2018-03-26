'use babel';
'use strict';

/** @jsx etch.dom */

const etch = require('etch');
const q = require('q');
const utils = require('../util/wizard-utils');
const EventEmitter = require('events');
const WizardField = require('./wizard-field');
const DirectoryPicker = require("./directory-picker");
const PickedFolder = require('./picked-folder');
const Configuration = require("../util/configuration");

const PAGE_START = 0;
const PAGE_DATA = 1;
const PAGE_DIRECTORY = 2;

const PAGE_COUNT = 3;

class Wizard {
  constructor (props, children) {
    this.props = props;
    this.currentContentIndex = -1;
    this.contentData = {};
    this.contentFolder = null;
    this.currentPage = PAGE_START;
    this.editorFields = require('../../editor-fields.json')
    this.eventEmitter = new EventEmitter();
    this.items = {};

    etch.initialize(this);
  }

  /* Component lifecycle methods */

  render(){
    switch (this.currentPage) {
      case PAGE_START:
        return this.renderStartPage();
        break;
      case PAGE_DATA:
        return this.renderContentFields();
        break;
      case PAGE_DIRECTORY:
        return this.renderPickFolder();
        break;
      default:
        this.currentPage = PAGE_START;
        return this.renderStartPage();
    }
  }

  update (props, children) {
    var self = this;
    this.props = props;
    return etch.update(this).then(() => {
      if(self.currentPage == PAGE_DATA){
        if(Object.keys(self.contentData).length == 0){
          self.applyDefaultValues();
        } else {
          self.applyValues();
        }
        self.refs.nextButton.disabled = false;
      } else if(self.currentPage == PAGE_DIRECTORY){
        self.refs.finishButton.disabled = true;
        var dirListener = (directory) => {
          self.contentFolder = directory;
          self.refs.pickedFolder.update({path: directory});
          self.refs.finishButton.disabled = false;
        };

        self.refs.dirPicker.emitter.removeListener("selectedDirectory", dirListener);
        self.refs.dirPicker.emitter.on("selectedDirectory", dirListener);
      }
    });
  }

  async destroy () {
    await etch.destroy(this)
  }

  /* Util and navigation methods */

  applyValues(){
    var self = this;
    Object.keys(this.contentData).forEach( (key) => {
      if(!self.refs[key]){
        return;
      }
      self.refs[key].setValue(self.contentData[key]);
    });
  }

  applyDefaultValues(){
    var self = this;
    if(this.currentPage == PAGE_DATA){
      this.editorFields[this.currentContentIndex].fields
      .filter((x) => x.visible)
      .forEach((field) => {
        //apply default value, if any
        if(field.default){
          self.refs[field.id].setValue(utils.eval(field.default));
        }
      });
    }
  }

  contentName(){
    if(this.currentContentIndex < 0){
      return "Content";
    }

    var ret = this.editorFields[this.currentContentIndex].title;
    if(!ret){
      ret = "Content";
    }
    return ret;
  }

  cloneDir(){
    return new Configuration().whereToClone();
  }

  getValues(){
    var self = this, result = {};
    self.editorFields[this.currentContentIndex].fields.forEach( (field) => {
      if(field.visible){
        result[field.id] = self.refs[field.id].getValue();
      } else {
        result[field.id] = utils.eval(field.default);
      }
    });
    return result;
  }

  goPrevious(){
    this.currentPage--;
    this.update(self.props);
  }

  goNext(){
    if(this.currentPage == PAGE_DATA){
      this.contentData = this.getValues();
    }
    this.currentPage++;
    this.update(self.props);
  }

  finish(){
    var values = this.contentData;
    var title = values.title || values.title.trim().length > 0 ? values.title : "new-content";
    var targetFolder = utils.uniqueContentFolder(this.contentFolder, title);
    var index = utils.generateContent(values, targetFolder)

    var response = {
      values: values,
      folder: targetFolder,
      index: index
    }

    this.fireComplete(response);
  }

  preloadItems(){
    var self = this;
    this.items = {};
    var deferred = q.defer();
    var selects = this.editorFields[this.currentContentIndex].fields
      .filter( (field) => field.type === "select");

    if(selects.length === 0){
      return q.fcall(() => true);
    }

    var promises = selects
      .map( (field) => {
        var thePath = utils.eval(field.options.path), promise = null;
        if(field.options.strategy === "mdmeta"){
          promise = utils.listMarkdownMetas;
        } else if(field.options.strategy === "json") {
          promise = utils.listCategories;
        } else {
          promise = q.fcall(() => []);
        }

        return promise(thePath, field.options.value, field.options.display);
      });

    q.all(promises).then( (items) => {
      // console.log("We got items", items);
      items.forEach( (item, i) => self.items[selects[i].id] = item);
      deferred.resolve(true);
    })

    return deferred.promise;
  }

  /* Rendering methods */

  renderTitle(){
    return <div>
      <span class="xclose icon icon-x" on={{click: this.fireClose}}></span>
      <h1>New {this.contentName()}</h1>
    </div>;
  }

  renderStartPage () {
    var self = this;
    return <div class='awe-wizard'>
      {this.renderTitle()}
      <div class = 'tool-bar tool-bar-top tool-bar-horizontal tool-bar-24px gutter-bottom'>
        {this.editorFields.map( (field, i) => self.renderNewContentButton(self, field, i))}
      </div>
    </div>
  }

  renderContentFields(){
    var self = this;
    var fields = this.editorFields[this.currentContentIndex].fields;

    return <div class='awe-wizard'>
      {this.renderTitle()}

      {fields.filter((x) => x.visible).map(this.renderField.bind(self))}

      {this.renderCommandButtons()}
    </div>
  }

  renderField(field, i){
    return <div class="block">
      <label>{field.display}</label>
      <WizardField ref={field.id} field={field} items={this.items[field.id]} tabindex={i + 1}></WizardField>
    </div>
  }

  renderPickFolder(){
    return <div ref="pageDirectory" class="awe-wizard">
      {this.renderTitle()}

      <PickedFolder ref="pickedFolder" rootPath={this.cloneDir()} path={this.contentFolder}></PickedFolder>

      <div class="scroll">
        <DirectoryPicker ref="dirPicker" path={this.cloneDir()}></DirectoryPicker>
      </div>

      {this.renderCommandButtons()}
    </div>
  }

  renderCommandButtons(){
    return <div class='block buttons'>
      <hr />
      <button ref="prevButton" class='inline-block btn icon icon-triangle-left' on={{click: this.goPrevious}}>Previous</button>
      {this.renderNextOrFinishButton()}
    </div>
  }

  renderNextOrFinishButton(){
    if(this.currentPage < PAGE_COUNT - 1)
      return <button ref="nextButton" class='inline-block btn icon icon-triangle-right' on={{click: this.goNext}}>Next</button>
    if(this.currentPage >= PAGE_COUNT - 1)
      return <button ref="finishButton" class='inline-block btn icon icon-verified' on={{click: this.finish}}>Finish</button>
  }

  renderNewContentButton(self, field, i){
    return <div on={{click:self.newContentButtonClicked}} attributes={{index: i}} class={"btn btn-default tool-bar-btn icon-" + field.icon}>
      <div>{field.title}</div>
    </div>
  }

  /* Event handling and emission methods */

  newContentButtonClicked(e){
    var self = this;
    this.currentContentIndex = Number(e.target.getAttribute("index"));
    this.currentPage = PAGE_DATA;

    this.contentData = {};
    this.contentFolder = null;

    //load select items first, then fire update
    this.preloadItems().then( () => self.update(this.props, []));
  }

  getEmitter() {
    return this.eventEmitter;
  }

  fireClose() {
    this.eventEmitter.emit("close");
  }

  fireComplete(response) {
    this.eventEmitter.emit("complete", response);
  }
}

module.exports = Wizard
