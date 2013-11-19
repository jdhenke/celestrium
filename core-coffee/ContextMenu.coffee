# provides an input box which can add nodes to the graph
define [], () ->

  class ContextMenu extends Backbone.View

    events:
      "contextmenu": "displayMenu"

    constructor: (@options) ->
      super()

    buttonClick: ->
        alert "you clicked on .. "

    init: (instances) ->

      instances["Layout"].addBottomRight @el
      @functions = []
      @functions.push @buttonClick
      @render()


    render: ->
      $container = $("<div />").addClass("radial_container")
      $ul = $("<ul />").addClass("list")
      $li = $("<li />").addClass("item")
      $myclass = $("<div />").addClass("my_class").text("Expand Nodes")
      $li.append $myclass


      $li2 = $("<li />").addClass("item")
      $myclass = $("<div />").addClass("my_class").text("Expand Nodes")
      $li2.append $myclass






      $ul.append $li
      $ul.append $li2
      $container.append $ul

      @$el.append $container

      functions = @functions



      @$(".radial_container").radmenu
          listClass: "list"
          itemClass: "item"
          radius: 100
          animSpeed: 400
          centerX: 30
          centerY: 100
          selectEvent: "click"
          onSelect: ($selected) -> # show what is returned

            console.dir $(".radial_container").radmenu("items")
            console.dir $selected



      rad_container = @$(".radial_container")

      rad_container.radmenu "show"


      """
      document.addEventListener "contextmenu", ((ev) ->
        ev.preventDefault()
        rad_container.radmenu "show"
        false
      ), false
      """

      return this

    displayMenu: (ev)->
      ev.preventDefault()
      return false