# provides an input box which can add nodes to the graph
define [], () ->

  class ContextMenu extends Backbone.View

    events:
      "contextmenu": "displayMenu"

    constructor: (@options) ->
      super()

    init: (instances) ->
      @render()
      instances["Layout"].addBottomRight @el


    render: ->
      $container = $("<div />").addClass("radial_container")
      $ul = $("<ul />").addClass("list")
      $li = $("<li />").addClass("item")
      $myclass = $("<div />").addClass("my_class").text("Expand Nodes")
      $li.append $myclass
      $ul.append $li
      $container.append $ul

      @$el.append $container

      @$(".radial_container").radmenu
          listClass: "list"
          itemClass: "item"
          radius: 100
          animSpeed: 400
          centerX: 30
          centerY: 100
          selectEvent: "click"
          onSelect: ($selected) ->
            alert "you clicked on .. " + $selected.index()

          angleOffset: 0

      rad_container = @$(".radial_container")

      document.addEventListener "contextmenu", ((ev) ->
        ev.preventDefault()
        rad_container.radmenu "show"
        false
      ), false

      return this

    displayMenu: (ev)->
      ev.preventDefault()
      console.log "hi"
      return false