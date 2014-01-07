requirejs.config

  baseUrl: "/base"

  paths:
    jquery: "lib/jquery"
    "jquery.typeahead": "lib/jquery.typeahead"
    underscore: "lib/underscore"
    backbone: "lib/backbone"
    d3: "lib/d3"
    celestrium: "dist/js/celestrium"
    tests: "test/js/tests"

  shim:
    "jquery.typeahead": ["jquery"]
    d3:
      exports: "d3"
    underscore:
      exports: "_"
    backbone:
      deps: ["underscore"]
      exports: "Backbone"
    "celestrium":
      deps: ['jquery', 'jquery.typeahead', 'underscore', 'backbone', 'd3']
      exports: "celestrium"
    "tests":
      deps: ["celestrium"]

  callback: () ->
    require ["tests"], () ->
      window.__karma__.start()
