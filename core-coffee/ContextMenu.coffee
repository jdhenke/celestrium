# provides an input box which can add nodes to the graph
define [], () ->

  class ContextMenu extends Backbone.View

    constructor: (@options) ->
      super()

    init: (instances) ->
      @functions = []
      @initializeMenu()

      # get mouse coordinates to center context menu
      that = @
      d3.select("html").on "mousemove", ->
        coordinates = d3.mouse(this)
        that.x = coordinates[0]
        that.y = coordinates[1]

      instances["Layout"].addContextMenu @el,@radial_container
      display = false
      @listenTo instances["KeyListener"], "down:77", (e) =>
        $(".radial_container").css "top", @y - 120
        $(".radial_container").css "left", @x - 70
        display = !display
        if display
          $(".radial_container").radmenu "show"
        else
          $(".radial_container").radmenu "hide"

    initializeMenu: ->
      $container = $("<div />").addClass("radial_container")
      @menu = $("<ul />").addClass("list")
      #add default option TODO: with numbers

      $container.append @menu
      @$el.append $container

      @addMenuOption "Nodes Selected"

    addMenuOption: (menuText, itemFunction, that)->
      $li = $("<li />").addClass("item")
      $myclass = $("<div />").addClass("my_class").text(menuText)
      $li.append $myclass
      @menu.append $li

      @functions.push itemFunction

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