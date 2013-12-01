# provides an input box which can add nodes to the graph
define [], () ->

  class ContextMenu extends Backbone.View

    events:
      "contextmenu": "displayMenu"

    constructor: (@options) ->
      super()

    DefaultOption: ->
        alert "you clicked on .. "

    init: (instances) ->
      @functions = []

      @instances = instances
      @initializeMenu()

      instances["Layout"].addContextMenu @el,@radial_container
      display = false
      @listenTo instances["KeyListener"], "down:80", () =>
        display = !display
        if display
          $(".radial_container").radmenu "show"
        else
          $(".radial_container").radmenu "hide"

    initializeMenu: ->
      $container = $("<div />").addClass("radial_container")
      @menu = $("<ul />").addClass("list")
      #add default option TODO: with numbers
      @addMenuOption "Nodes Selected", @DefaultOption

      $container.append @menu
      @$el.append $container

    addMenuOption: (menuText, itemFunction, that)->
      $li = $("<li />").addClass("item")
      menuLabel = menuText.replace " ","_"
      $myclass = $("<div />").addClass("my_class").addClass(menuLabel).text(menuText)
      @functions.push itemFunction
      $li.append $myclass
      @menu.append $li

      functions = @functions

      $(".radial_container").radmenu
          listClass: "list"
          itemClass: "item"
          radius: 100
          animSpeed: 400
          centerX: 30
          centerY: 100
          selectEvent: "click"
          onSelect: ($selected) -> # show what is returned
            functions[$selected.index()].apply(that)



    displayMenu: (ev)->
      ev.preventDefault()
      return false