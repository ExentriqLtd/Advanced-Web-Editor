'use babel'
/** @jsx etch.dom */

const etch = require('etch')
const utils = require('../util/wizard-utils')

class Wizard {
  // Required: Define an ordinary constructor to initialize your component.
  constructor (props, children) {
    // perform custom initialization here...
    this.editorFields = require('../../editor-fields.json')

    utils.listCategories('/home/emanuele/Desktop/mapr_workdir/mapr.com', '/src/main/metalsmith/json/blog_categories_all.json')
    .then((categories) => console.log('Categories:', categories))

    utils.listMarkdownMetas('/home/emanuele/Desktop/mapr_workdir/mapr.com-content', '/en/blog/author/')
    .then((metas) => console.log('Metas:', metas))

    // then call `etch.initialize`:
    etch.initialize(this)
  }

  // Required: The `render` method returns a virtual DOM tree representing the
  // current state of the component. Etch will call `render` to build and update
  // the component's associated DOM element. Babel is instructed to call the
  // `etch.dom` helper in compiled JSX expressions by the `@jsx` pragma above.
  render () {
    var children = [];
    var title = <h1>New Content</h1>;
    var contents = <div>

    </div>
    children.push(title);
    return etch.dom('div',{className: 'awe-wizard'}, ...children);
  }

  // Required: Update the component with new properties and children.
  update (props, children) {
    // perform custom update logic here...
    // then call `etch.update`, which is async and returns a promise
    return etch.update(this)
  }

  // Optional: Destroy the component. Async/await syntax is pretty but optional.
  async destroy () {
    // call etch.destroy to remove the element and destroy child components
    await etch.destroy(this)
    // then perform custom teardown logic here...
  }
}

module.exports = Wizard
