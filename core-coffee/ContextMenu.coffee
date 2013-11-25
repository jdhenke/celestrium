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
      console.log "instances"
      @functions = []

      @instances = instances
      console.log @instances
      @initializeMenu()

      instances["Layout"].addContextMenu @el,@radial_container

    initializeMenu: ->
      $container = $("<div />").addClass("radial_container")
      @menu = $("<ul />").addClass("list")
      #add default option TODO: with numbers
      @addMenuOption "NODES", @DefaultOption
      $container.append @menu
      @$el.append $container

    addRelatedNodes: ->
      provider = @instances
      provider.getLinkedNodes @instances["NodeSelection"].getSelectedNodes(), (nodes) =>
          _.each nodes, (node) =>
            provider.graphModel.putNode node if provider.nodeFilter node

    addMenuOption: (menuText, itemFunction)->
      console.log "menu add "
      $li = $("<li />").addClass("item")
      $myclass = $("<div />").addClass("my_class").addClass("").text(menuText)
      #@functions.push itemFunction
      console.log itemFunction
      @addRelatedNodes
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
            functions[$selected.index()]()

      rad_container = $(".radial_container")
      rad_container.radmenu "show"

    displayMenu: (ev)->
      ev.preventDefault()
      return false