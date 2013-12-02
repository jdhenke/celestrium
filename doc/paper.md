Celestrium
==========

Sharon Hao

Justin Helbert

Joe Henke

## Abstract

Celestrium is a collection of requirejs modules which enables developers to easily create interfaces to visualize and explore large graph based datasets.
It is designed to be database agnostic and minimize the activation energy required by developers, easily interfacing with JSON endpoints to populate the visualization.
This paper discusses how and why Celestrium's plugin architecture was designed the way it is and argues it could be useful in other contexts.
Additionally, it explains implementations of several interfaces which used Celestrium, each for different data sets, and compares the necessary lines of code, showing Celestrium to be broadly useful without requiring much additional effort.

## Intro

Celestrium is a frontend architecture for the web to visualize graphs.
Prior to Celestrium, several javascript graph visualization frameworks existed.
They and their differences with Celestrium are listed here.

[**Canviz**](http://stackoverflow.com/a/5715325) can render standard `.dot` files as a graph, which Celestrium cannot do. 
However, the resulting visualization is static - the nodes cannot be moved. 
In Celestrium, nodes can be clicked, selected and dragged, continuously altering the layout of the graph.

[**Javascript InfoVis Toolkit**](http://philogb.github.io/jit/index.html) and [**VivaGraphJS**](https://github.com/anvaka/VivaGraphJS) are more dynamic and can detect user interaction with nodes, for example.
However, they are only responsible for rendering the graph's layout. 
Ultimately, what separates Celestrium from VivaGraphJS and all other libraries is it has extra plug-and-play features builtin such as:

* Being able to manipulate and view distributions of link strengths
* Running graph analysis algorithms on the visible subgraph
* Providing an API to easily integrate with JSON server endpoints

In a sense, Celestrium takes graph visualization platforms further by providing default, but replaceable, implementations of common functionalities to make creating graph visualizations easier.
Celestrium is intended for the case where a user wants to visually analyze a graph database which is too big to understand all at once and so must be investigated from a particular node or nodes outwards, bottom up.

## Example Interface

> Should concisely explain the directory structure of a simple application
> as well as what the resulting interface looks like and how to use it

## Implementation

### Plugin Architecture

Celestrium is implemented as a collection of requirejs plugins, so the design pattern which dictates the interaction between these plugins is critical. 
Celestrium leverages `requirejs` to provide access to plugin *definitions*. 
Then, building on top of that, Celestrium uses a custom infrastructure to provide access to the *instance* of each plugin. 
The difference may or may not be obvious, but it is important in understanding Celestrium's design.

- **Definitions**, conceptually, provide the *ability* to create a certain type of object.
- **Instances** - are the *instantiated objects* themselves.

To make this concrete, consider the GraphModel plugin. 
The *definition* is the class definition in Coffeescript, but an *instance* is a GraphModel object.
This may seem trivial, but requirejs only provides the definitions, not the instances, which is an issue because plugins almost always need access to the *instance* of another plugin and more specifically, they need access to the *same* instance. 

For example, if the GraphView instance was listening to a different GraphModel instance than the DataProvider instance, (which adds nodes and links to it,) the GraphView would never receive that information because it's listening to a completely different object. 
This seems to suggest a singleton pattern, where each class automatically creates an instance of itself and attaches it to the class definition. 
However, plugins often need parameters in their constructor that must be specified by the developer somehow i.e. the DOM element in which to house the workspace.
Thus plugin definitions can't automatically instantiate themselves without providing an entry for custom parameters.

Celestrium addresses these needs by separating the entry of parameters and instances of other plugins into these separate places:

* A plugin's **constructor** accepts arguments from the developer.
* A plugin's **init** function accepts a dictionary of instances of other plugins.

The code which facilitates this is actually very concise and is shown here. This is out of a special module called `Celestrium`, which has one function, `init`:

```coffeescript
init: (pluginsDict, callback) ->
  pluginPaths = _.keys(pluginsDict)
  instances = {}
  require pluginPaths, (plugins...) ->
    _.each plugins, (plugin, i) ->
      options = pluginsDict[pluginPaths[i]]
      instance = new plugin(options)
      instance.init instances
      instances[pluginPaths[i]] = instance
    callback(instances) if callback?
```

So, `Celestrium.init` accepts a dictionary, `pluginsDict`, with keys being requirejs paths to the plugins to be instantiated and the values being the arguments to the constructor.

So iterating through `pluginsDict`, a list of plugin instances, `instances`, is maintained, and each plugin is

* instantiated with it's given arguments
* `init`ed with `instances` as the argument
* added to `instances` itself, so later plugins may access it.

An issue here is that no circular dependencies may exist.
It is unclear if maintaining this invariant is good design anyway or a limitation of this approach.

An alternative could be to perform two passes.
On the first, each plugin is created and added to the `instances` dictionary.
Then on the second pass, each instance would be `init`ed with the dictionary of every instance, even the last one.
This was not chosen as it then exposes plugins which have not yet been `init`ed to be used by other plugins.
So, the current specification dictates that if plugin `A` needs an instance of plugin `B`, `B` should appear before `A` in the dictionary.

Ultimately, this architecture formalizes the method by which instances of plugins are accessed by other plugins and allows developers to pass arguments to the necessary plugins.
In fact, we feel this is a good design approach for *any* interface which has distinct components, because it removes the boilerplate of constructing each plugin manually and providing it the required instances of other plugins.

### Modeling a Graph

Moving from the plugin architecture to a single plugin, the GraphModel plugin, this section discusses how Celestrium models a graph.

d3's force directed layout is the what currently renders the actual graph onscreen, so any deviation from d3's graph representation would require the data to be put into that format anyway.
So, it seemed optimal, practically speaking, to use d3's representation, but it was not attempted to optimize for other uses cases. 
This may be worth investigating if alternative layout methods are used.

d3 uses an array of javascript objects to represent the nodes.
Links are stored as an array of javascript objects with `source` and `target` attributes which are the actual node objects themselves.

> TODO: scalability/bottleneck analysis

### Interfacing with the Backend

Now that Celestrium can internally represent a graph, it must interface with the source of the data.
To do so, Celestrium provides DataProvider.
DataProvider is an abstract class definition which need only be extended to include the functionality to connect to the server in order to fulfill the following specification:

#### `getLinks(node, nodes, callback)`

* `node` is a single node in the graph
* `nodes` is a list of nodes in the graph
* `callback` is a function which should be called with an array of links, `A`, st. `A[i]` is the link from `node` to `nodes[i]`.
  * A link should be a javascript object with a `strength` attribute in `[0,1]` and can optionally have a `direction` attribute in `{forward, backward, bidrectional}` indicating the a directed link.

#### `getLinkedNodes(nodes, callback)`

* `nodes` is a an array of nodes
* `callback` is a function which should be called with an array of `nodes` which are linked to any node in `nodes`.

Note that both of these functions accept existing nodes as arguments - so where does the first node come from?
A function such as `getAllNodes` is computationally infeasible for some datasets, so to not limit Celestrium to data sets which can be completely enumerated, it was left out of the DataProvider specification.
For data sets that can accomplish this, the NodeSearch plugin allows lookup of a node by name.
For data sets that cannot accomplish this, it is left to the developer to provide some form of random access to its nodes.

## Examples

*It's hard to think about thinking without thinking about thinking about something.*

In this spirit, this section provides concrete examples of using Celestrium. 
The first is an interface which has no backend - it simply produces random edges between nodes named after the Phonetic Alphabet.
This random interface is then used as a baseline in comparison to implementations of real data sets.
Because some data sets generate their graphs differently i.e. sparse matrices vs. redirecting to a REST API vs. static data, only the main script and data provider scripts are compared, however other scripts which were necessary for each interface to function are described in each section for reference.

### Example Interfaces

#### Random

This example shows the necessary code to create the functionality for a random graph generator. 
This implementation is also more thoroughly explained to illustrate the general structure of an implementation.

> NOTE: `PhoneticAlphabet` is just an array of strings which is the phonetic alphabet.

##### `main.coffee`

```coffeescript
requirejs.config
  baseUrl: "/celestrium/core/"
  paths:
    local: "../../"

require ["Celestrium", "local/PhoneticAlphabet"],
(Celestrium, PhoneticAlphabet) ->

  plugins =
    "Layout":
      el: document.querySelector "body"
    "KeyListener":
      document.querySelector "body"
    "GraphModel":
      nodeHash: (node) -> node.text
      linkHash: (link) -> link.source.text + link.target.text
    "GraphView": {}
    "NodeSelection": {}
    "Sliders": {}
    "ForceSliders": {}
    "LinkDistribution": {}
    "NodeSearch":
      local: PhoneticAlphabet
    "local/RandomDataProvider": {}

  Celestrium.init plugins
```

This is the entry point for code execution.

The first lines configure different requirejs paths.

* `baseUrl` should be the path to the compiled output of Celestrium's `core-coffee` directory relative to the page it is included on.
* `local` specifies the path to the compiled output of plugins that were created specifically for this example and are not part of Celestrium. 
This path is relative to `baseUrl`.

Then `require` is used to load the `Celestrium` module definition and initiate the desired plugins for this interface.
`Celestrium.init` expects a dictionary with keys as the `requirejs` path to the plugin to be instantiated and values as the object to be fed as an argument to that plugin's constructor, as described in the Implementation Section.

##### `random.coffee`

```coffeescript
define ["DataProvider", "local/PhoneticAlphabet"],
(DataProvider, PhoneticAlphabet) ->
  class RandomDataProvider extends DataProvider
    getLinks: (node, nodes, callback) ->
      callback _.map nodes, () ->
        "strength": Math.max(0, (Math.random() - 0.5) * 2)
        "direction": _.sample [null, "forward", "backward", "bidirectional"]
    getLinkedNodes: (nodes, callback) ->
      callback _.chain(PhoneticAlphabet)
        .sample(5)
        .map (word) ->
          "text": word
        .value()
```

As described in the implementation section, `getLinks` returns an array of links between `node` and `nodes`. 
In this case, it's 0 half the time and randomly between [0,1] the other half.
It's directionality is also random.

`getLinkedNodes` returns all nodes linked to any node in `nodes`, which in this case is 5 random entries from the Phonetic Alphabet.

And that's it! The resulting interface looks like this:

> TODO: Picture

#### Emails

> TODO: @haosharon

#### Github Collaboration

> TODO: @jhelbert

#### Semantic Networks

> TODO: @jdhenke

### Implementation Cost Comparisons

> TODO: 
> * compare the each implementation's main and data provider wrt. lines of code
> * graphs would be good

## Conclusion

> TODO
