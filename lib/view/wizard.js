'use babel'
/** @jsx etch.dom */

const etch = require('etch');
const q = require('q');
const utils = require('../util/wizard-utils');
const fieldRenderer = require('../util/field-renderer');
const EventEmitter = require('events');
const WizardField = require('./wizard-field');

class WizardEventEmitter extends EventEmitter {}

class Wizard {
  // Required: Define an ordinary constructor to initialize your component.
  constructor (props, children) {
    this.props = props;
    this.currentContent = -1;
    this.editorFields = require('../../editor-fields.json')
    this.eventEmitter = new WizardEventEmitter();
    this.items = {};

    // then call `etch.initialize`:
    etch.initialize(this)
  }

  // Required: The `render` method returns a virtual DOM tree representing the
  // current state of the component. Etch will call `render` to build and update
  // the component's associated DOM element. Babel is instructed to call the
  // `etch.dom` helper in compiled JSX expressions by the `@jsx` pragma above.
  render(){
    if(this.currentContent < 0){
      return this.renderStartPage();
    } else {
      return this.renderContent();
    }
  }

  renderStartPage () {
    var self = this;
    var children = [];

    this.buttons = [];

    this.editorFields.forEach( (field, i) => self.buttons.push(self.renderButton(self, field, i)));
    var contents = etch.dom('div',{className: 'tool-bar tool-bar-top tool-bar-horizontal tool-bar-24px gutter-bottom'}, ...this.buttons);
    children.push(this.renderTitle());
    children.push(contents);
    return etch.dom('div',{className: 'awe-wizard'}, ...children);
  }

  renderTitle(){
    return <div>
      <span class="xclose" on={{click: this.fireClose}}>
        X
      </span>
      <h1>New {this.contentName()}</h1>
    </div>;
  }

  contentName(){
    if(this.currentContent < 0){
      return "Content";
    }

    var ret = this.editorFields[this.currentContent].title;
    if(!ret){
      ret = "Content";
    }
    return ret;
  }

  renderContent(){
    var fields = this.editorFields[this.currentContent].fields;
    var children = [];
    children.push(this.renderTitle());
    children.push(this.renderFieldsTable(fields));
    children.push(this.renderCommandButtons());
    return etch.dom('div',{className: 'awe-wizard'}, ...children);
  }

  renderFieldsTable(fields){
    var self = this;
    return <table>
      <thead></thead>
      <tbody>
        {fields.filter((x) => x.visible).map((field) =>
          <tr>
            <td class="label">
              <label>{field.display}</label>
            </td>
            <td class="field">
              <WizardField field={field} items={self.items[field.id]}></WizardField>
            </td>
          </tr>
        )}
      </tbody>
    </table>
  }

  renderCommandButtons(){
    return <div></div>
  }

  renderButton(self, field, i){
    return <div on={{click:self.buttonClicked}} attributes={{index: i}} class={"btn btn-default tool-bar-btn icon-" + field.icon}>
      <div>{field.title}</div>
    </div>
  }

  buttonClicked(e){
    var self = this;
    // console.log("Button clicked", e);
    this.currentContent = Number(e.target.getAttribute("index"));

    //load select items first, then fire update
    this.preloadItems().then( () => self.update(this.props, []));
  }

  preloadItems(){
    var self = this;
    this.items = {};
    var deferred = q.defer();
    var selects = this.editorFields[this.currentContent].fields
      .filter( (field) => field.type === "select");

    if(selects.length === 0){
      return q.fcall(() => true);
    }

    var promises = selects
      .map( (field) => {
        var thePath = utils.eval(field.options.path);
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
      console.log("We got items", items);
      items.forEach( (item, i) => self.items[selects[i].id] = item);
      deferred.resolve(true);
    })

    return deferred.promise;
  }

  // Required: Update the component with new properties and children.
  update (props, children) {
    // perform custom update logic here...
    // then call `etch.update`, which is async and returns a promise
    this.props = props;
    return etch.update(this)
  }

  // Optional: Destroy the component. Async/await syntax is pretty but optional.
  async destroy () {
    // call etch.destroy to remove the element and destroy child components
    await etch.destroy(this)
    // then perform custom teardown logic here...
  }

  gatherValues() {
    var values = this.editorFields[this.currentContent].fields
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
