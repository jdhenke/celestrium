# makeshift collection class. triggers only "change" event. supports push() and
# clear(). clear efficiently removes all elements from the array.
MakeLightCollection = () ->
  output = []
  _.extend output, Backbone.Events
  output.push = (obj) ->
    Array.prototype.push.call(this, obj)
    @trigger("add", obj)
    @trigger("change")
  output.clear = (obj) ->
    @length = 0
    @trigger("change")
  return output

# renders the graph using d3's force directed layout
class Graph extends Backbone.View

  @uri: "Graph"

  constructor: (@options) ->
    super(@options)
    @nodes = MakeLightCollection()
    @links = MakeLightCollection()
    @listenTo @nodes, "change", @update
    @listenTo @links, "change", @update
    @render()

  render: ->
    initialWindowWidth = @$el.width()
    initialWindowHeight = @$el.height()
    @force = d3.layout.force()
      .size([initialWindowWidth, initialWindowHeight])
      .charge(-500)
      .gravity(0.2)

    svg = d3.select(@el).append("svg:svg").attr("pointer-events", "all")
    zoom = d3.behavior.zoom()

    # create arrowhead definitions
    defs = svg.append("defs")

    defs
      .append("marker")
      .attr("id", "Triangle")
      .attr("viewBox", "0 0 20 15")
      .attr("refX", "15")
      .attr("refY", "5")
      .attr("markerUnits", "userSpaceOnUse")
      .attr("markerWidth", "20")
      .attr("markerHeight", "15")
      .attr("orient", "auto")
      .append("path")
        .attr("d", "M 0 0 L 10 5 L 0 10 z")

    defs
      .append("marker")
      .attr("id", "Triangle2")
      .attr("viewBox", "0 0 20 15")
      .attr("refX", "-5")
      .attr("refY", "5")
      .attr("markerUnits", "userSpaceOnUse")
      .attr("markerWidth", "20")
      .attr("markerHeight", "15")
      .attr("orient", "auto")
      .append("path")
        .attr("d", "M 10 0 L 0 5 L 10 10 z")

    # add standard styling
    style = $("
    <style>
      .nodeContainer .node text { opacity: 0.5; }
      .nodeContainer .selected circle { fill: steelblue; }
      .nodeContainer .node:hover text { opacity: 1; }
      .nodeContainer:hover { cursor: pointer; }
      .linkContainer .link { stroke: gray; opacity: 0.5; }
    </style>
    ")
    $("html > head").append(style)

    # outermost wrapper - this is used to capture all zoom events
    zoomCapture = svg.append("g")

    # this is in the background to capture events not on any node
    # should be added first so appended nodes appear above this
    zoomCapture.append("svg:rect")
           .attr("width", "100%")
           .attr("height", "100%")
           .style("fill-opacity", "0%")

    # lock infrastracture to ignore zoom changes that would
    # typically occur when dragging a node
    translateLock = false
    currentZoom = undefined
    @force.drag().on "dragstart", ->
      translateLock = true
      currentZoom = zoom.translate()
    .on "dragend", ->
      zoom.translate currentZoom
      translateLock = false

    # add event listener to actually affect UI

    # ignore zoom event if it's due to a node being dragged

    # otherwise, translate and scale according to zoom
    zoomCapture.call(zoom.on("zoom", -> # ignore double click to zoom
      return  if translateLock
      workspace.attr "transform",
        "translate(#{d3.event.translate}) scale(#{d3.event.scale})"

    )).on("dblclick.zoom", null)

    # inner workspace which nodes and links go on
    # scaling and transforming are abstracted away from this
    workspace = zoomCapture.append("svg:g")

    # containers to house nodes and links
    # so that nodes always appear above links
    linkContainer = workspace.append("svg:g").classed("linkContainer", true)
    nodeContainer = workspace.append("svg:g").classed("nodeContainer", true)
    return this

  update: ->
    nodes = @nodes
    filteredLinks = @links
    @force.nodes(nodes).links(filteredLinks).start()
    link = @linkSelection = d3.select(@el)
      .select(".linkContainer")
      .selectAll(".link")
      .data filteredLinks, (link) -> link.source.text + link.target.text
    linkEnter = link.enter().append("line")
      .attr("class", "link")
      .attr('marker-end', (link) ->
        'url(#Triangle)' if link.direction is 'forward' or\
           link.direction is 'bidirectional')
      .attr('marker-start', (link) ->
        'url(#Triangle2)' if link.direction is 'backward' or\
           link.direction is 'bidirectional')

    @force.start()
    link.exit().remove()
    link.attr "stroke-width", (link) -> 5 * link.strength
    node = @nodeSelection = d3.select(@el)
      .select(".nodeContainer")
      .selectAll(".node")
      .data nodes, (node) -> node.text
    nodeEnter = node.enter()
      .append("g")
      .attr("class", "node")
      .call(@force.drag)
    nodeEnter.append("text")
         .attr("dy", "20px")
         .style("text-anchor", "middle")
         .text (d) ->
           d.text

    nodeEnter.append("circle")
         .attr("r", 5)
         .attr("cx", 0)
         .attr("cy", 0)

    @trigger "enter:node", nodeEnter
    @trigger "enter:link", linkEnter
    node.exit().remove()
    @force.on "tick", ->
      link.attr("x1", (d) ->
        d.source.x
      ).attr("y1", (d) ->
        d.source.y
      ).attr("x2", (d) ->
        d.target.x
      ).attr("y2", (d) ->
        d.target.y
      )

      node.attr "transform", (d) ->
        "translate(#{d.x},#{d.y})"

  getNodeSelection: ->
    return @nodeSelection

  getLinkSelection: ->
    return @linkSelection

  getForceLayout: ->
    return @force

celestrium.register Graph
