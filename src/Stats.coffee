# provides an interface to register a statistic with a simple label
# `addStat(label)` adds a stat with said label and returns a function
# `update(newVal)` which can be called with udpated values of the stat
# and the displayed statistic will be updated
class StatsView extends Backbone.View

  @uri: "Stats"
  @needs:
    graphModel: "GraphModel"

  constructor: (@options) ->
    super(@options)
    @render()
    @listenTo @graphModel, "change", @update

  render: ->
    container = $("<div />").addClass("graph-stats-container").appendTo(@$el)
    @$table = $("<table border=\"0\"/>").appendTo(container)
    @updateNodes = @addStat("Nodes")
    @updateLinks = @addStat("Links")
    @update()
    return this
  update: ->
    @updateNodes @graphModel.getNodes().length
    @updateLinks @graphModel.getLinks().length
  addStat: (label) ->
    $label = $("""<td class="graph-stat-label">#{label}: </td>""")
    $stat = $("""<td class="graph-stat"></td>)""")
    $row = $("<tr />").append($label).append($stat)
    @$table.append($row)
    return (newVal) ->
      $stat.text(newVal)

celestrium.register StatsView