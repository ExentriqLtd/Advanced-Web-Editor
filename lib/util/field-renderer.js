'use babel'
/** @jsx etch.dom */

const etch = require('etch');

var renderer = {}

var defaultRenderer = (field) => {
  return <atom-text-editor id={field.id} attributes={{mini: true}}></atom-text-editor>
}

renderer.string = defaultRenderer;
renderer.file = defaultRenderer;

renderer.select = (field, items) => {
  return <select if={field.id}>
    {items.map( (item) => <option value={item.value}>{item.display}</option>)}
  </select>
}

renderer.render = (field, items) => {
  var type = field.type;
  if(renderer.hasOwnProperty(type) && type !== "render"){
    return renderer[type](field, items);
  } else {
    return defaultRenderer(field);
  }
}

module.exports = renderer;
