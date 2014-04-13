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