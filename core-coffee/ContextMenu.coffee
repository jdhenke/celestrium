# provides an input box which can add nodes to the graph
define [], () ->

  class ContextMenu extends Backbone.View

    TestOption: ->
      console.log "test"

    constructor: (@options) ->
      super()

    init: (instances) ->
      # needed to set instance attributes
      that = @

      @menuFunctions = []
      @menuThat = []

      @selectionCount = 0
      instances["NodeSelection"].on "change", ->
        that.selectionCount = @.getSelectedNodes().length
        $(".Nodes_Selected").text("Nodes Selected:" + that.selectionCount)

      # get mouse coordinates to center context menu
      d3.select("html").on "mousemove", ->
        coordinates = d3.mouse(this)
        that.x = coordinates[0]
        that.y = coordinates[1]

      display = false
      @listenTo instances["KeyListener"], "down:77", (e) =>
        $(".Nodes_Selected").text("Nodes Selected:" + that.selectionCount)
        # center context menu based on mouse coordinates
        $(".radial_container").css "top", @y - 120
        $(".radial_container").css "left", @x - 70
        display = !display
        if display
          $(".radial_container").radmenu "show"
        else
          $(".radial_container").radmenu "hide"

      instances["Layout"].addContextMenu @el,@radial_container
      @initializeMenu()
      @addMenuOption "Nodes Selected", @TestOption, @




    initializeMenu: ->
      $container = $("<div />").addClass("radial_container")
      @menu = $("<ul />").addClass("list")
      #add default option TODO: with numbers

      $container.append @menu
      @$el.append $container



    addMenuOption: (menuText, itemFunction, that)->
      $li = $("<li />").addClass("item")
      menuClass = menuText.replace " ","_"
      $myclass = $("<div />").addClass("my_class").addClass(menuClass).text(menuText)
      $li.append $myclass
      @menu.append $li

      @menuFunctions.push itemFunction
      @menuThat.push that



    renderMenu: ->
      menuFunctions = @menuFunctions
      menuThat = @menuThat
      console.log menuThat
      $(".radial_container").radmenu
          listClass: "list"
          itemClass: "item"
          radius: 100
          animSpeed: 400
          centerX: 30
          centerY: 100
          selectEvent: "click"
          onSelect: ($selected) -> # show what is returned
            menuFunctions[$selected.index()].apply(menuThat[$selected.index()])