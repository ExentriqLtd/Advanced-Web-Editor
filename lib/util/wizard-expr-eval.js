"use strict";
"use babel";

const moment = require("moment");
const Configuration = require("./configuration");

const EXPR_START = "{"
const EXPR_END = "}"

var functions = {};

functions.now = () => moment().utc().format()

functions.mapr = () => new Configuration().whereToClonePreviewEngine()

functions.maprcontent = () => new Configuration().whereToClone()

function _eval(value) {
  if (!value) {
    return value;
  }

  var startExp = value.indexOf(EXPR_START);
  var endExp = value.indexOf(EXPR_END);

  if (startExp >= 0 && endExp > startExp) {
    var expr = value.substring(startExp + EXPR_START.length, endExp);
    if (functions[expr]) {
      return value.substring(0, startExp) + functions[expr]() + value.substring(endExp + EXPR_END.length);
    } else {
      return value;
    }
  } else {
    return value;
  }
}

module.exports = _eval;
