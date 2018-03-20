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
  // Required: Define an ordinary constructor to initialize your component.
  constructor (props, children) {
    this.props = props;
    this.currentContentIndex = -1;
    this.contentData = {};
    this.contentFolder = null;
    this.currentPage = PAGE_START;
    this.editorFields = require('../../editor-fields.json')
    this.eventEmitter = new EventEmitter();
    this.items = {};

    // then call `etch.initialize`:
    etch.initialize(this);
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

  // Required: The `render` method returns a virtual DOM tree representing the
  // current state of the component. Etch will call `render` to build and update
  // the component's associated DOM element. Babel is instructed to call the
  // `etch.dom` helper in compiled JSX expressions by the `@jsx` pragma above.
  render(){
    switch (this.currentPage) {
      case PAGE_START:
        return this.renderStartPage();
        break;
      case PAGE_DATA:
        return this.renderContent();
        break;
      case PAGE_DIRECTORY:
        return this.renderPickFolder();
        break;
      default:
        this.currentPage = PAGE_START;
        return this.renderStartPage();
    }
  }

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

  renderContent(){
    var self = this;
    var fields = this.editorFields[this.currentContentIndex].fields;

    return <div class='awe-wizard'>
      {this.renderTitle()}

      <table>
        <thead></thead>
        <tbody>
          {fields.filter((x) => x.visible).map((field) =>
            <tr>
              <td class="label">
                <label>{field.display}</label>
              </td>
              <td class="field">
                <WizardField ref={field.id} field={field} items={self.items[field.id]}></WizardField>
              </td>
            </tr>
          )}
        </tbody>
      </table>

      {this.renderCommandButtons()}
    </div>
  }

  renderPickFolder(){
    return <div ref="pageDirectory" class="awe-wizard">
      {this.renderTitle()}

      <PickedFolder ref="pickedFolder" path={this.contentFolder}></PickedFolder>

      <div class="scroll">
        <DirectoryPicker ref="dirPicker" path={this.cloneDir()}></DirectoryPicker>
      </div>

      {this.renderCommandButtons()}
    </div>
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
      console.log(field, field.id, field.visible)
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
    this.currentPage++;
    this.update(self.props);
  }

  renderCommandButtons(){
    return <div class='block buttons'>
      <hr />
      <button class='inline-block btn icon icon-triangle-left' on={{click: this.goPrevious}}>Previous</button>
      <button class='inline-block btn icon icon-triangle-right' on={{click: this.goNext}}>Next</button>
    </div>
  }

  renderNewContentButton(self, field, i){
    return <div on={{click:self.newContentButtonClicked}} attributes={{index: i}} class={"btn btn-default tool-bar-btn icon-" + field.icon}>
      <div>{field.title}</div>
    </div>
  }

  newContentButtonClicked(e){
    var self = this;
    this.currentContentIndex = Number(e.target.getAttribute("index"));
    this.currentPage = PAGE_DATA;

    this.contentData = {};
    this.contentFolder = null;

    //load select items first, then fire update
    this.preloadItems().then( () => self.update(this.props, []));
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

  // Required: Update the component with new properties and children.
  update (props, children) {
    var self = this;
    // perform custom update logic here...
    // then call `etch.update`, which is async and returns a promise
    this.props = props;
    return etch.update(this).then(() => {
      if(self.currentPage == PAGE_DATA){
        self.applyDefaultValues();
      } else if(self.currentPage == PAGE_DIRECTORY){
        var dirListener = (directory) => {
          self.contentFolder = directory;
          self.refs.pickedFolder.update({path: directory});
        };

        self.refs.dirPicker.emitter.removeListener("selectedDirectory", dirListener);
        self.refs.dirPicker.emitter.on("selectedDirectory", dirListener);
      }
    });
  }

  // Optional: Destroy the component. Async/await syntax is pretty but optional.
  async destroy () {
    // call etch.destroy to remove the element and destroy child components
    await etch.destroy(this)
    // then perform custom teardown logic here...
  }

  gatherValues() {
    var values = this.editorFields[this.currentContentIndex].fields
  }

  getEmitter() {
    return this.eventEmitter;
  }

  fireClose() {
    this.eventEmitter.emit("close");
  }

  fireOk() {
    this.eventEmitter.emit("ok");
  }
}

module.exports = Wizard
