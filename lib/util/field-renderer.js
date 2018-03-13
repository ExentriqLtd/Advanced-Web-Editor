'use babel'
/** @jsx etch.dom */

const etch = require('etch')

var renderer = {}

var defaultRenderer = (field) =>
  <atom-text-editor id={field.id} attributes={{mini: true}}></atom-text-editor>

renderer.string = defaultRenderer;
renderer.file = defaultRenderer;

renderer.render = (field) => {
  var type = field.type;
  if(renderer.hasOwnProperty(type) && type !== "render"){
    return renderer[type](field);
  } else {
    return defaultRenderer(field);
  }
}

module.exports = renderer;
