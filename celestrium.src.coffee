class Celestrium

  constructor: () ->
    @defs = {}

  register: (Plugin) ->
    @defs[Plugin.uri] = Plugin

  # defines instances in an order which satisfies their dependencies
  init: (plugins, callback) ->

    # dictionary which is populated below
    # maps: uri -> instance of that plugin
    instances = {}

    # list of uris to be instantiated
    # is reduced to [] below
    queue = (uri for uri, arg of plugins)

    # recursively instantiates dependencies of uri
    # instantiates uri, assigning attributes per its @needs
    # adds the instances to instances
    instantiate = (uri, parents) =>

      # check for a circular dependency
      if uri in parents
        cycleStr = JSON.stringify parents.concat [uri]
        throw new Error "Circular dependency detected: #{cycleStr}"

      # confirm class was registered
      if not @defs[uri]?
        throw new Error "#{uri} has not been registered"

      # remove uri from queue
      index = queue.indexOf uri
      if index > -1
        queue.splice index, 1
      else
        throw new Error "#{uri} was not specified in celestrium.init"

      ### create instance of plugin identified by `uri` ###

      # create temporary class definition to avoid modifying global one
      class Temp extends @defs[uri]
      Temp.needs ?= {}
      for attr, parentURI of Temp.needs
        do (attr, parentURI) ->
          if not instances[parentURI]?
            instantiate parentURI, parents.concat [uri]
          Temp.prototype[attr] = instances[parentURI]

      # finally, create instance, using argument from main; add to instances
      arg = plugins[uri]
      instance = new Temp(arg)
      instances[uri] = instance

    # instantiate all plugins in the queue
    while queue.length > 0
      instantiate queue[0], []

    callback instances if callback?

# make `celestrium` a globally accessible object
window.celestrium = new Celestrium()

# you should extend this class to create your own data provider

class DataProvider

  @uri: "DataProvider"
  @needs:
    graphModel: "GraphModel"
    keyListener: "KeyListener"
    nodeSelection: "NodeSelection"

  constructor: () ->
    @keyListener.on "down:16:187", () =>
      @searchAround (nodes, links) =>
        _.each nodes, (node) =>
          @graphModel.putNode node
        _.each links, (link) =>
          @graphModel.putLink link

  # calls callback with these arguments
  #  nodes - array of nodes, disjoint from current nodes
  #  links - array of links, with source and target as indices
  #          into original nodes + new nodes
  searchAround: (callback) ->

celestrium.register DataProvider

# an example implementation of a data provider which shows
# the dependencies between modules in celestrium

class DependencyProvider extends celestrium.defs["DataProvider"]

  @uri: "DependencyProvider"

  searchAround: (callback) ->
    # get list of unique, related nodes disjoin from current nodes
    nodes = @graphModel.getNodes()
    newNodes = _.chain(@nodeSelection.getSelectedNodes())
      .map((node) ->
        needs = celestrium.defs[node.text].needs
        needs ?= {}
        return _.values needs
      )
      .flatten()
      .filter((text) =>
        return not @graphModel.get("nodeSet")[text]
      )
      .uniq()
      .map((text) -> {text: text})
      .value()

    # get links between
    #  - all current nodes and new nodes
    #  - all new nodes and eachother
    needs = (a, b) ->
      A = celestrium.defs[a.text]
      output =  A.needs? and b.text in _.values(A.needs)
      return output
    links = []
    _.each nodes, (oldNode, i) ->
      _.each newNodes, (newNode, j) ->
        if needs(oldNode, newNode)
          links.push
            source: i
            target: nodes.length + j
            strength: 0.8
            direction: "forward"
        else if needs(newNode, oldNode)
          links.push
            source: i
            target: nodes.length + j
            strength: 0.8
            direction: "backward"
    _.each newNodes, (node1, i) ->
      _.each newNodes, (node2, j) ->
        return if i is j
        if needs(node1, node2)
          links.push
            source: nodes.length + i
            target: nodes.length + j
            strength: 0.8
            direction: "forward"
    callback(newNodes, links)

celestrium.register DependencyProvider

# includes a spacing slider to adjust the charge in the force directed layout
class ForceSliders

  @uri: "ForceSliders"
  @needs:
    sliders: "Sliders"
    graphView: "GraphView"

  constructor: (instances) ->
    scale = d3.scale.linear()
      .domain([-20, -2000])
      .range([0, 100])
    force = @graphView.getForceLayout()
    @sliders.addSlider "Spacing", scale(force.charge()), (val) ->
      force.charge scale.invert val
      force.start()

celestrium.register ForceSliders

class GraphModel extends Backbone.Model

  @uri: "GraphModel"

  initialize: ->
    @set
      "nodes": []
      "links": []
      "nodeSet": {}
      "nodeHash": (node) -> node.text
      "linkHash": (link) -> link.source.text + link.target.text

  getNodes: ->
    return @get "nodes"

  getLinks: ->
    return @get "links"

  hasNode: (node) ->
    return @get("nodeSet")[@get("nodeHash")(node)]?

  putNode: (node) ->
    # ignore if node is already in this graph
    return if @hasNode(node)

    # modify node to have attribute accessor functions
    nodeAttributes = @get("nodeAttributes")
    node.getAttributeValue = (attr) ->
      nodeAttributes[attr].getValue node

    # commit this node to this graph
    @get("nodeSet")[@get("nodeHash")(node)] = true
    @trigger "add:node", node
    @pushDatum "nodes", node

  putLink: (link) ->
    link.strength ?= 1
    @pushDatum "links", link
    @trigger "add:link", link

  linkHash: (link) ->
    @get("linkHash")(link)

  pushDatum: (attr, datum) ->
    data = @get(attr)
    data.push datum
    @set attr, data

    ###
    QA: this is not already fired because of the rep-exposure of get.
    `data` is the actual underlying object
    so even though set performs a deep search to detect changes,
    it will not detect any because it's literally comparing the same object.

    Note: at least we know this will never be a redundant trigger
    ###

    @trigger "change:#{attr}"
    @trigger "change"

  # also removes links incident to any node which is removed
  filterNodes: (filter) ->
    nodeWasRemoved = (node) ->
      _.some removed, (n) ->
        _.isEqual n, node
    linkFilter = (link) ->
      not nodeWasRemoved(link.source) and not nodeWasRemoved(link.target)
    removed = []
    wrappedFilter = (d) =>
      decision = filter(d)
      unless decision
        removed.push d
        delete @get("nodeSet")[@get("nodeHash")(d)]
      decision
    @filterAttribute "nodes", wrappedFilter
    @filterLinks linkFilter

  filterLinks: (filter) ->
    @filterAttribute "links", filter

  filterAttribute: (attr, filter) ->
    filteredData = _.filter(@get(attr), filter)
    @set attr, filteredData

celestrium.register(GraphModel)

# renders the graph using d3's force directed layout

class LinkFilter extends Backbone.Model
  initialize: () ->
    @set "threshold", 0.75
  filter: (links) ->
    return _.filter links, (link) =>
      return link.strength > @get("threshold")
  connectivity: (value) ->
    if value
      @set("threshold", value)
    else
      @get("threshold")

class GraphView extends Backbone.View

  @uri: "GraphView"
  @needs:
    model: "GraphModel"

  constructor: (@options) ->
    super(@options)
    @model.on "change", @update.bind(this)
    @render()

  initialize: (options) ->
    # filter between model and visible graph
    # use identify function if not defined
    @linkFilter = new LinkFilter(this)
    @listenTo @linkFilter, "change:threshold", @update

  render: ->
    initialWindowWidth = @$el.width()
    initialWindowHeight = @$el.height()
    @force = d3.layout.force()
      .size([initialWindowWidth, initialWindowHeight])
      .charge(-500)
      .gravity(0.2)
    @linkStrength = (link) =>
      return (link.strength - @linkFilter.get("threshold")) /
        (1.0 - @linkFilter.get("threshold"))
    @force.linkStrength @linkStrength
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
    nodes = @model.get("nodes")
    links = @model.get("links")
    filteredLinks = if @linkFilter then @linkFilter.filter(links) else links
    @force.nodes(nodes).links(filteredLinks).start()
    link = @linkSelection = d3.select(@el)
      .select(".linkContainer")
      .selectAll(".link")
      .data(filteredLinks, @model.get("linkHash"))
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
    link.attr "stroke-width", (link) => 5 * (@linkStrength link)
    node = @nodeSelection = d3.select(@el)
      .select(".nodeContainer")
      .selectAll(".node")
      .data(nodes, @model.get("nodeHash"))
    nodeEnter = node.enter()
      .append("g")
      .attr("class", "node")
      .call(@force.drag)
    nodeEnter.append("text")
         .attr("dx", 12)
         .attr("dy", ".35em")
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

  getLinkFilter: ->
    return @linkFilter

celestrium.register GraphView

# fires down:key1:key2... with all currently down keys on keydowns

# TODO: release state on loss of window focus

class KeyListener

  @uri: "KeyListener"

  constructor: () ->
    target = document.querySelector "body"
    _.extend this, Backbone.Events
    state = {}
    watch = [17, 65, 27, 46, 13, 16, 80, 187, 191]

    # this ignores keypresses from inputs
    $(window).keydown (e) =>
      return  if e.target isnt target or not _.contains(watch, e.which)
      state[e.which] = e
      keysDown = _.chain(state).map((event, which) ->
        which
      ).sortBy((which) ->
        which
      ).value()
      eventName = "down:#{keysDown.join(':')}"
      @trigger eventName, e
      delete state[e.which] if e.isDefaultPrevented()

    # this ignores keypresses from inputs
    $(window).keyup (e) ->
      return if e.target isnt target
      delete state[e.which]

celestrium.register KeyListener

# manages overall layout of page
# provides functions to add DOM elements to different locations of the screen
# automatically puts links to celestrium repo in bottom right
# and a button to show/hide all other helpers

class PluginWrapper extends Backbone.View
  className: 'plugin-wrapper'

  initialize: (args) ->
    @plugin = args.plugin
    @pluginName = args.name
    @collapsed = false
    @render()

  events:
    'click .plugin-controls .header': 'close'

  close: (e) ->
    if @collapsed
      @collapsed = false
      # expand
      @expand @$el.find('.plugin-content')
    else
      @collapsed = true
      # collapse
      @collapse @$el.find('.plugin-content')

  expand: (el) ->
    el.slideDown(300)
    @$el.removeClass('collapsed')

  collapse: (el) ->
    el.slideUp(300)
    @$el.addClass('collapsed')

  render: ->
    @controls = $ """
      <div class=\"plugin-controls\">
        <div class=\"header\">
          <span>#{@pluginName}</span>
          <div class=\"arrow\"></div>
        </div>
      </div>
    """
    @content = $("<div class=\"plugin-content\"></div>")
    @content.append @plugin

    @$el.append @controls
    @$el.append @content

class Layout extends Backbone.View

  @uri: "Layout"

  constructor: (@options) ->
    super(@options)
    # a dictionary of lists, so we can order plugins
    @pluginWrappers = {}
    @render()

  render: ->
    @pluginContainer = $("<div class=\"plugin-container\"/>")
    @$el.append @pluginContainer
    return this

  renderPlugins: ->
    keys = _.keys(@pluginWrappers).sort()
    _.each keys, (key, i) =>
      pluginWrappersList = @pluginWrappers[key]
      _.each pluginWrappersList, (pluginWrapper) =>
        @pluginContainer.append pluginWrapper.el

  addCenter: (el) ->
    @$el.append el

  addPlugin: (plugin, pluginOrder, name="Plugin") ->
    pluginOrder ?= Number.MAX_VALUE
    pluginWrapper = new PluginWrapper(
      plugin: plugin
      name: name
      order: pluginOrder
      )
    if _.has @pluginWrappers, pluginOrder
      @pluginWrappers[pluginOrder].push pluginWrapper
    else
      @pluginWrappers[pluginOrder] = [pluginWrapper]
    @renderPlugins()

celestrium.register Layout

# provides a variably smoothed PDF of the distribution link strengths.
# also provides a slider on that distribution
# which filters out links with weight below that threshold.

margin =
  top: 10
  right: 10
  bottom: 40
  left: 10

width = 200 - margin.left - margin.right
height = 200 - margin.top - margin.bottom
minStrength = 0
maxStrength = 1

class LinkDistributionView extends Backbone.View

  @uri: "LinkDistribution"
  @needs:
    graphModel: "GraphModel"
    graphView: "GraphView"
    sliders: "Sliders"

  className: "link-pdf"

  constructor: (@options) ->
    @windowModel = new Backbone.Model()
    @windowModel.set("window", 10)
    @listenTo @windowModel, "change:window", @paint
    super(@options)
    @listenTo @graphModel, "change:links", @paint
    @render()

  render: ->

    ### one time setup of link strength pdf view ###

    # create cleanly transformed workspace to generate display
    @svg = d3.select(@el)
            .append("svg")
            .classed("pdf", true)
            .attr("width", width + margin.left + margin.right)
            .attr("height", height + margin.top + margin.bottom)
            .append("g")
            .classed("workspace", true)
            .attr("transform", "translate(#{margin.left},#{margin.top})")
    @svg.append("g")
      .classed("pdfs", true)

    # add standard styling
    style = $("
    <style>
      .pdf { margin-left: auto; margin-right: auto; width: 200px; }
      .pdf .axis text { font-size: 6pt; }
      .pdf .axis path, .pdf .axis line {
        fill: none; stroke: #000; shape-rendering: crispEdges;
      }
      .pdf .axis .label { font-size: 10pt; text-anchor: middle; }
      .pdf path { fill: steelblue; }
      .pdf .threshold-line {
        stroke: #000; stroke-width: 2px; cursor: ew-resize;
      }
      .pdf.drag { cursor: ew-resize; }
    </style>
    ")
    $("html > head").append(style)

    # scale mapping link strength to x coordinate in workspace
    @x = d3.scale.linear()
      .domain([minStrength, maxStrength])
      .range([0, width])

    # create axis
    xAxis = d3.svg.axis()
      .scale(@x)
      .orient("bottom")
    bottom = @svg.append("g")
      .attr("class", "x axis")
      .attr("transform", "translate(0,#{height})")
    bottom.append("g")
      .call(xAxis)
    bottom.append("text")
      .classed("label", true)
      .attr("x", width / 2)
      .attr("y", 35)
      .text("Link Strength")

    # initialize plot
    @paint()

    ### create draggable threshold line ###

    # create threshold line
    d3.select(@el).select(".workspace")
      .append("line")
      .classed("threshold-line", true)

    # x coordinate of threshold
    thresholdX = @x(@graphView.getLinkFilter().get("threshold"))

    # draw initial line
    d3.select(@el).select(".threshold-line")
      .attr("x1", thresholdX)
      .attr("x2", thresholdX)
      .attr("y1", 0)
      .attr("y2", height)

    # handling dragging
    @$(".threshold-line").on "mousedown", (e) =>
      $line = @$(".threshold-line")
      pageX = e.pageX
      originalX = parseInt $line.attr("x1")
      # TODO: don't use a global selector
      d3.select(".pdf").classed("drag", true)
      $(window).one "mouseup", () ->
        $(window).off "mousemove", moveListener
        d3.select(".pdf").classed("drag", false)
      moveListener = (e) =>
        @paint()
        dx = e.pageX - pageX
        newX = Math.min(Math.max(0, originalX + dx), width)
        @graphView.getLinkFilter().set("threshold", @x.invert(newX))
        $line.attr("x1", newX)
        $line.attr("x2", newX)
      $(window).on "mousemove", moveListener
      e.preventDefault()

    # for chained calls
    return this

  paint: ->

    ### function called everytime link strengths change ###

    # use histogram layout with many bins to get discrete pdf
    layout = d3.layout.histogram()
      .range([minStrength, maxStrength])
      .frequency(false) # tells d3 to use probabilities, not counts
      .bins(100) # determines the granularity of the display

    # raw distribution of link strengths
    values = _.pluck @graphModel.getLinks(), "strength"
    sum = 0
    cdf = _.chain(layout(values))
      .map (bin) ->
        "x": bin.x, "y": sum += bin.y
      .value()
    halfWindow = Math.max 1, parseInt(@windowModel.get("window")/2)
    pdf = _.map cdf, (bin, i) ->
      # get quantiles
      q1 = Math.max 0, i - halfWindow
      q2 = Math.min cdf.length - 1, i + halfWindow
      # get y value at quantiles
      y1 = cdf[q1]["y"]
      y2 = cdf[q2]["y"]
      # get slope
      slope = (y2 - y1) / (q2 - q1)
      # return slope as y to produce a smoothed derivative
      return "x": bin.x, "y": slope

    # scale mapping cdf to y coordinate in workspace
    maxY = _.chain(pdf)
      .map((bin) -> bin.y)
      .max()
      .value()
    @y = d3.scale.linear()
      .domain([0, maxY])
      .range([height, 0])

    # create area generator based on pdf
    area = d3.svg.area()
      .interpolate("monotone")
      .x((d) => @x(d.x))
      .y0(@y(0))
      .y1((d) => @y(d.y))

    ###

    define the x and y points to use for the visible links.
    they should be the points from the original pdf that are above
    the threshold

    to avoid granularity issues (jdhenke/celestrium#75),
    we also prepend this list of points with a point with x value exactly at
    the threshold and y value that is the average of it's neighbors' y values

    ###

    threshold = @graphView.getLinkFilter().get("threshold")
    visiblePDF = _.filter pdf, (bin) ->
      bin.x > threshold
    if visiblePDF.length > 0
      i = pdf.length - visiblePDF.length
      if i > 0
        y = (pdf[i-1].y + pdf[i].y) / 2.0
      else
        y = pdf[i].y
      visiblePDF.unshift
        "x": threshold
        "y": y

    # set opacity on area, bad I know
    pdf.opacity = 0.25
    visiblePDF.opacity = 1

    data = [pdf]
    data.push visiblePDF unless visiblePDF.length is 0

    path = d3
      .select(@el)
      .select(".pdfs")
      .selectAll(".pdf")
        .data(data)
    path.enter()
      .append("path")
      .classed("pdf", true)
    path.exit().remove()
    path
      .attr("d", area)
      .style("opacity", (d) -> d.opacity)

celestrium.register LinkDistributionView

# provides details of the selected nodes

class NodeDetailsView extends Backbone.View

  constructor: (@options) ->
    super()

  init: (instances) ->
    @selection = instances["NodeSelection"]
    @selection.on "change", @update.bind(this)
    @listenTo instances["KeyListener"], "down:80", () => @$el.toggle()
    instances["Layout"].addPlugin @el, @options.pluginOrder, 'Node Details'
    @$el.toggle()

  update: ->
    @$el.empty()
    selectedNodes = @selection.getSelectedNodes()
    $container = $("<div class=\"node-profile-helper\"/>").appendTo(@$el)
    blacklist = ["index", "x", "y", "px", "py", "fixed", "selected", "weight"]
    _.each selectedNodes, (node) ->
      $nodeDiv = $("<div class=\"node-profile\"/>").appendTo($container)
      $("""
        <div class=\"node-profile-title\">#{node['text']}</div>
      """).appendTo $nodeDiv
      _.each node, (value, property) ->
        $("""
          <div class=\"node-profile-property\">#{property}:  #{value}</div>
        """).appendTo $nodeDiv  if blacklist.indexOf(property) < 0

class NodeSelection

  @uri: "NodeSelection"
  @needs:
    keyListener: "KeyListener"
    graphView: "GraphView"
    graphModel: "GraphModel"

  constructor: () ->

    _.extend this, Backbone.Events

    @linkFilter = @graphView.getLinkFilter()

    @listenTo @keyListener, "down:17:65", @selectAll
    @listenTo @keyListener, "down:27", @deselectAll
    @listenTo @keyListener, "down:46", @removeSelection
    @listenTo @keyListener, "down:13", @removeSelectionCompliment

    # handle selecting and deselecting nodes
    clickSemaphore = 0
    @graphView.on "enter:node", (nodeEnterSelection) =>
      nodeEnterSelection.on("click", (datum, index) =>
        # ignore drag
        return  if d3.event.defaultPrevented
        datum.fixed = true
        clickSemaphore += 1
        savedClickSemaphore = clickSemaphore
        setTimeout (=>
          if clickSemaphore is savedClickSemaphore
            @toggleSelection datum
            datum.fixed = false
          else
            # increment so second click isn't registered as a click
            clickSemaphore += 1
            datum.fixed = false
        ), 250
      ).on "dblclick", (datum, index) =>
        @selectConnectedComponent datum

  renderSelection: () ->
    nodeSelection = @graphView.getNodeSelection()
    if nodeSelection
      nodeSelection.call (selection) ->
        selection.classed "selected", (d) ->
          d.selected

  filterSelection: (filter) ->
    _.each @graphModel.getNodes(), (node) ->
      node.selected = filter(node)

    @renderSelection()

  selectAll: () ->
    @filterSelection (n) ->
      true

    @trigger "change"

  deselectAll: () ->
    @filterSelection (n) ->
      false

    @trigger "change"

  toggleSelection: (node) ->
    node.selected = not node.selected
    @trigger "change"
    @renderSelection()

  removeSelection: () ->
    @graphModel.filterNodes (node) ->
      not node.selected

  removeSelectionCompliment: () ->
    @graphModel.filterNodes (node) ->
      node.selected

  getSelectedNodes: ->
    _.filter @graphModel.getNodes(), (node) ->
      node.selected

  selectBoundedNodes: (dim) ->
    selectRect = {
      left: dim.x
      right: dim.x + dim.width
      top: dim.y
      bottom: dim.y + dim.height
    }

    intersect = (rect1, rect2) ->
      return !(rect1.right < rect2.left ||
        rect1.bottom < rect2.top ||
        rect1.left > rect2.right ||
        rect1.top > rect2.bottom)

    @graphView.getNodeSelection().each (datum, i) ->
      bcr = this.getBoundingClientRect()
      datum.selected = intersect(selectRect, bcr)

    @trigger 'change'
    @renderSelection()

  # select all nodes which have a path to node
  # using links meeting current Connectivity criteria
  selectConnectedComponent: (node) ->

    visit = (text) ->
      unless _.has(seen, text)
        seen[text] = 1
        _.each graph[text], (ignore, neighborText) ->
          visit neighborText

    # create adjacency list version of graph
    graph = {}
    lookup = {}
    _.each @graphModel.getNodes(), (node) ->
      graph[node.text] = {}
      lookup[node.text] = node

    _.each @linkFilter.filter(@graphModel.getLinks()), (link) ->
      graph[link.source.text][link.target.text] = 1
      graph[link.target.text][link.source.text] = 1

    # perform DFS to compile connected component
    seen = {}
    visit node.text

    # toggle selection appropriately
    # selection before ==> selection after
    #       none ==> all
    #       some ==> all
    #       all  ==> none
    allTrue = true
    _.each seen, (ignore, text) ->
      allTrue = allTrue and lookup[text].selected

    newSelected = not allTrue
    _.each seen, (ignore, text) ->
      lookup[text].selected = newSelected

    # notify listeners of change
    @trigger "change"

    # update UI
    @renderSelection()

celestrium.register NodeSelection

class SelectionLayer

  @uri: "SelectionLayer"
  @needs:
    graphView: "GraphView"
    nodeSelection: "NodeSelection"

  constructor: () ->
    @$parent = @graphView.$el
    _.extend this, Backbone.Events

    @_intializeDragVariables()
    @render()

  render: =>
    @canvas = $('<canvas/>').addClass('selectionLayer')
                .css('position', 'absolute')
                .css('top', 0)
                .css('left', 0)
                .css('pointer-events', 'none')[0]

    @_sizeCanvas()

    @$parent.append @canvas

    @_registerEvents()

  _sizeCanvas: =>
    ctx = @canvas.getContext('2d')
    ctx.canvas.width = $(window).width()
    ctx.canvas.height = $(window).height()

  _intializeDragVariables: =>
    @dragging = false
    @startPoint =
      x: 0
      y: 0
    @prevPoint =
      x: 0
      y: 0
    @currentPoint =
      x: 0
      y: 0

  _setStartPoint: (coord) =>
    @startPoint.x = coord.x
    @startPoint.y = coord.y

  _registerEvents: =>
    $(window).resize (e) =>
      @_sizeCanvas()

    @$parent.mousedown (e) =>
      if e.shiftKey
        @dragging = true
        _.extend @startPoint, {
          x: e.clientX
          y: e.clientY
        }

        _.extend @currentPoint, {
          x: e.clientX
          y: e.clientY
        }
        @determineSelection()

        return false

    @$parent.mousemove (e) =>
      if e.shiftKey
        if @dragging
          _.extend @prevPoint, @currentPoint
          _.extend @currentPoint, {
            x: e.clientX
            y: e.clientY
          }
          @renderRect()
          @determineSelection()
          return false

    @$parent.mouseup (e) =>
      @dragging = false
      @_clearRect @startPoint, @currentPoint
      _.extend @startPoint, {
        x: 0
        y: 0
      }
      _.extend @currentPoint, {
        x: 0
        y: 0
      }

    $(window).keyup (e) =>
      if e.keyCode == 16
        @dragging = false
        @_clearRect @startPoint, @prevPoint
        @_clearRect @startPoint, @currentPoint

  determineSelection: =>
    # find out what nodes are in box
    rectDim = @rectDim(@startPoint, @currentPoint)
    @nodeSelection.selectBoundedNodes rectDim

  renderRect: =>
    @_clearRect @startPoint, @prevPoint
    @_drawRect @startPoint, @currentPoint

  rectDim: (startPoint, endPoint) ->
    dim = {}
    dim.x = if startPoint.x < endPoint.x then startPoint.x else endPoint.x
    dim.y = if startPoint.y < endPoint.y then startPoint.y else endPoint.y
    dim.width = Math.abs(startPoint.x - endPoint.x)
    dim.height = Math.abs(startPoint.y - endPoint.y)
    return dim

  _drawRect: (startPoint, endPoint) =>
    dim = @rectDim startPoint, endPoint
    ctx = @canvas.getContext '2d'
    ctx.fillStyle = 'rgba(255, 255, 0, 0.2)'
    ctx.fillRect dim.x, dim.y, dim.width, dim.height

  _clearRect: (startPoint, endPoint) =>
    dim = @rectDim startPoint, endPoint
    ctx = @canvas.getContext '2d'
    ctx.clearRect dim.x, dim.y, dim.width, dim.height

celestrium.register SelectionLayer
###

provides an interface to add sliders to the ui

`addSlider(label, initialValue, onChange)` does the following
  - shows the text `label` next to the slider
  - starts it at `initialValue`
  - calls `onChange` when the value changes
    with the new value as the argument

sliders have range [0, 100]

###

class SlidersView extends Backbone.View

  @uri: "Sliders"

  constructor: (@options) ->
    super(@options)
    @render()

  render: () ->
    $container = $ """
      <div class="sliders-container">
        <table border="0">
        </table>
      </div>
    """
    $container.appendTo @$el
    return this

  addSlider: (label, initialValue, onChange) ->

    $row = $ """
      <tr>
        <td class="slider-label">#{label}: </td>
        <td><input type="range" min="0" max="100"></td>
      </tr>
    """

    $row.find("input")
      .val(initialValue)
      .on "input", () ->
        val = $(this).val()
        onChange(val)
        $(this).blur()

    @$("table").append $row

celestrium.register SlidersView

class StaticProvider extends celestrium.defs["DataProvider"]
  @uri: "StaticProvider"
  constructor: (nodes, links) ->
    super()
    _.each nodes, (node) => @graphModel.putNode node
    _.each links, (link) => @graphModel.putLink link

  searchAround: (callback) ->

class StaticProvider extends celestrium.defs["DataProvider"]

  @uri: "StaticProvider"

  constructor: (data) ->
    super()
    [@nodes, @links] = [data.nodes, data.links]
    @graph = {}
    @linkDict = {}
    _.each @links, (link) =>
      [source, target] = [link.source, link.target]
      @graph[source.text] ?= []
      @graph[source.text].push link
      @graph[target.text] ?= []
      @graph[target.text].push link
      @linkDict[@graphModel.linkHash(link)] = link
    _.each @nodes, (node) => @graphModel.putNode node
    _.each @links, (link) => @graphModel.putLink link

  searchAround: (callback) ->
    selectedNodes = @nodeSelection.getSelectedNodes()

    newNodes = _.chain(selectedNodes)
      .map((node) =>
        links = @graph[node.text]
        links ?= []
        _.map links, (link) ->
          if link.source is node
            return link.target
          else
            return link.source
      ).flatten()
      .uniq()
      .filter((node) =>
        not @graphModel.hasNode node
      ).value()

    getLink = (node1, node2) =>
      @linkDict[@graphModel.linkHash({source:node1, target:node2})]

    links = []
    _.each newNodes, (newNode) =>
      _.each @graphModel.getNodes(), (oldNode) ->
        link1 = getLink(newNode, oldNode)
        link2 = getLink(oldNode, newNode)
        links.push link1 if link1?
        links.push link2 if link2?

    _.each newNodes, (newNode1, i) ->
      _.each newNodes, (newNode2, j) ->
        return if i is j
        link = getLink(newNode1, newNode2)
        links.push link if link?

    callback(newNodes, links)

celestrium.register StaticProvider

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