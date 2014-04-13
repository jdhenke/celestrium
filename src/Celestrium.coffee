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
