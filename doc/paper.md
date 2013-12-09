Celestrium
==========

Sharon Hao, Justin Helbert, Joe Henke

MIT 6.885

Professor Madden

## Abstract

Celestrium is a collection of requirejs modules which enables developers to easily create interfaces to visualize and explore large graph based datasets.
It is designed to be database agnostic and minimize the activation energy required by developers.
It easily interfaces with JSON server endpoints to populate the visualization.
This paper presents an example visualization of a random graph created by using celestrium.
It then discusses how and why Celestrium's plugin architecture was designed the way it is and argues it could be useful in other contexts.
Additionally, Celestrium was purposefully developed to support three different data sets in an effort to keep its use cases general as well as inspire a diverse set of functionalities.
Celestrium's effectiveness is evaluated through qualitative descriptions of these interface's implementations and is found to be general and powerful enough to support all of them.
Many ideas are presented as possibilities for future work.
This includes a quantative analysis of the scalability of the visualization itself, which found Celestrium to be very responsive for reasonably sized data sets which humans could understand but also established its limitations, which could be improved in the future.

## Table of Contents

* Introduction
* Example Interface
* Celestrium Implementation
* Three Interface Implementations
* Suggested Future Work
* Conclusion

## Introduction

Celestrium is a frontend architecture for the web to visualize graphs.
Prior to Celestrium, several javascript graph visualization frameworks existed.
They and their differences with Celestrium are listed here.

[**Canviz**](http://stackoverflow.com/a/5715325) can render standard `.dot` files as a graph, which Celestrium cannot do.
However, the resulting visualization is static - the nodes cannot be moved.
In Celestrium, nodes can be clicked, selected and dragged, continuously altering the layout of the graph.

[**Javascript InfoVis Toolkit**](http://philogb.github.io/jit/index.html) and [**VivaGraphJS**](https://github.com/anvaka/VivaGraphJS) are more dynamic and can detect user interaction with nodes, for example.
However, they are only responsible for rendering the graph's layout.
Ultimately, what separates Celestrium from VivaGraphJS and all other libraries is it has extra plug-and-play features builtin such as:

* Being able to manipulate and view the distributions of link strengths
* Running graph analysis algorithms on the visible subgraph
* Providing an API to easily communicate with JSON server endpoints

In a sense, Celestrium takes graph visualization platforms further by providing default, but replaceable, implementations of common functionalities to make creating graph visualizations easier.
Celestrium is intended for the case where a user wants to visually analyze a graph database which is too big to understand all at once and so must be investigated from a particular node or nodes outwards, bottom up.

## Example Interface

Here is an example of an interface that was created using Celestrium, which renders a graph with nodes as the phonetic alphabet and randomly generates links between them.

![image](https://f.cloud.github.com/assets/1418690/1701103/cc9a13f0-6040-11e3-815d-3be41a920182.png)

First, note that this is not the entire graph.
Celestrium allows the user to dynamically bring in parts of the entire graph.
A user can do this by searching for a specific node and adding it using the Node Search plugin.
Additionally, a user can pull in neighbors of nodes already in Celestrium and explore the graph by continually branching out from desired nodes.
Celestrium also automatically includes the links between the nodes currently on the graph, keeping the visualized graph consistent with the entire graph.

The graph itself is logically composed of nodes and edges.
Each node can have a brief text description.
Nodes can be selected and are shown in blue when they are.
Links between nodes can be undirected, directed in one direction or bidirectional.

Moving to the toolbar on the right, these each provide ways to manipulate or gain access to information about the current graph.
The "Spacing" slider allows the nodes to be moved closer or farther apart from each other.
The "Smooth" slider allows the granularity of the Link Strength Distribution to be adjusted.
The "Link Strength Distribution" chart shows an approximate PDF of the link strength distributions currently present in Celestrium.
The vertical, black bar is the minimum strength a link must have to be rendered.
This allows a user to dynamically adjust the connectedness of the graph so it is understandable to them.
Lastly, "Node Search" is an autocompleted text input box which allows a user to add any node they wish to Celestrium.

There are more plugins not included in this example and are described in the next section.

With a basic understanding of the types of interfaces Celestrium allows to be built, we now describe how Celestrium itself is implemented.

## Celestrium Implementation

### Plugin Architecture

Celestrium is implemented as a collection of requirejs plugins, so the design pattern which dictates the interaction between these plugins is critical.
Celestrium leverages `requirejs` to provide access to plugin *definitions*.
Then, building on top of that, Celestrium uses a custom infrastructure to provide access to the *instance* of each plugin.
The difference may or may not be obvious, but it is important in understanding Celestrium's design.

- **Definitions**, conceptually, provide the *ability* to create a certain type of object.
- **Instances** - are the *instantiated objects* themselves.

To make this concrete, consider three plugins which interact with eachother.

* GraphView is responsible for rendering the graph on the screen and listens for changes to the GraphModel
* GraphModel contains the underlying node and link objects which describe the currently visualize graph
* DataProvider listens to the GraphView for certain user actions and when fired, contacts the server and updates the GraphModel with new nodes or links

The *definition* of GraphModel is the class definition in Coffeescript, but an *instance* is a GraphModel object.
This may seem trivial, but requirejs only provides the definitions, not the instances, which is an issue because plugins almost always need access to the instance of another plugin and more specifically, they need access to the *same* instance.

If the GraphView instance was listening to a different GraphModel instance than the DataProvider instance, the GraphView would never receive that information because it's listening to a completely different object.
This seems to suggest a singleton pattern, where each class automatically creates an instance of itself and attaches it to the class definition.
However, plugins often need parameters in their constructor that must be specified by the developer somehow i.e. the DOM element in which to house the workspace.
Thus plugin definitions can't automatically instantiate themselves without providing an entry for custom parameters by the developer.

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
* `init`ed with `instances` as the argument - this includes all previously created instances from the previous iterations
* added to `instances` itself, so later plugins may access it.

An issue here is that no circular dependencies may exist.
It is unclear if maintaining this invariant is good design regardless or a limitation of this approach.

An alternative could be to perform two passes.
On the first, each plugin is created and added to the `instances` dictionary.
Then on the second pass, each instance would be `init`ed with the dictionary of every instance, so even the first `init`ed plugin has access to the instance of the last `init`ed plugin.
This was not chosen as it then exposes plugins which have not yet been `init`ed to be used by other plugins.
So, the current specification dictates that if plugin `A` needs an instance of plugin `B`, `B` should appear before `A` in the dictionary.

Ultimately, this architecture formalizes the method by which instances of plugins are accessed by other plugins and allows developers to pass arguments to the necessary plugins as well.
In fact, we feel this is a good design approach for *any* interface which has distinct components, because it removes the boilerplate of constructing each plugin manually and providing it the required instances of other plugins.

### Plugin Descriptions

Again, Celestrium is composed of many individual plugins which depend on each other.
The default plugins included with Celestrium are described here.
Note that an interface can choose which of these plugins to include and can also define their own plugins to be included in this infrastructure.

__ContextMenu__
* a circular popup menu (toggled by pressing ‘m’) with actions concerning selected nodes
* developers can add new options with `addMenuOption: (menuText, itemFunction, that)`

![image](https://f.cloud.github.com/assets/774269/1708574/bd940a48-6110-11e3-8449-1ed4b7d2428f.png)

__DataProvider__
* abstract class that developer extends to connect Celestrium to their data set, in most cases a server
* developers specify these two functionalities
  * `getLinks(node, nodes, callback)` which should call `callback` with an array of links between `node` and each node in `nodes` respectively.
  * `getLinkedNodes(nodes, callback)` should call `callback` with an array of nodes which are neighbors of any node in `nodes`.

__GraphModel__
* Core underlying model of the graph
* contains getter and setter methods for Nodes and Links

__GraphView__
* renders graph with data from GraphModel plugin using d3 libraries
* provides update function to re-render the graph when GraphModel changes

![image](https://f.cloud.github.com/assets/774269/1708494/3e834936-610f-11e3-8f64-cb5826882932.png)

__KeyListener__
* allows hotkeys to fire events from any plugin
* built-in hotkeys include ctrl+A to select all nodes, ESC to deselect all nodes, 'm' to toggle the ContextMenu

__Layout__
* Manages overall UI layout of page
* provides functions to add DOM elements to containers in parts of the screen

__LinkDistribution__

* provides a variably smoothed PDF of the distribution of link strengths.
* A slider on the PDF filters links, such that only links with weight about the threshold are visible on the graph.


__LinkDistributionNormalizer__
* scales link weights of various distributions to the range [0,1]
* Available transformations are linear, logarithmic (base 2 and base 10), and percentile.

__NodeSearch__
* Provides an input box to add a single node to the graph
* developer supplies a method in the constructor to get a list of all nodes in the graph

![image](https://f.cloud.github.com/assets/774269/1708506/7735c830-610f-11e3-90ef-d501a856346a.png)

__NodeSelection__
* allows nodes to be selected or unselected
* provides functions to access the state of the selected nodes


![image](https://f.cloud.github.com/assets/774269/1708503/6d3374ae-610f-11e3-8d2a-a7e148bccb1e.png)

__Sliders__
* provides an interface to add sliders to the ui
* function to add a new slider: `addSlider(label, initialValue, onChange)`

![image](https://f.cloud.github.com/assets/774269/1708499/5fe59cbe-610f-11e3-9bf6-040af4abcf4e.png)

Now that all the plugins have been listed, two plugins are next discussed in more detail: GraphModel and DataProvider.

### Modeling a Graph

GrahpModel defines how Celestrium models a graph.
d3's force directed layout is the what currently renders the actual graph onscreen, so any deviation from d3's graph representation would require the data to be put into that format anyway.
So, it seemed optimal, practically speaking, to use d3's representation, but it was not attempted to optimize for other uses cases.
This may be worth investigating if alternative layout methods are used.

d3 uses an array of javascript objects to represent the nodes.
Links are stored as an array of javascript objects with `source` and `target` attributes which are the actual node objects themselves.

### Interfacing with the Full Graph

Now that Celestrium can internally represent a graph, it must interface with the full source of the data.
To do so, Celestrium provides the DataProvider plugin.
DataProvider is an abstract class definition which only requires two functions to be implemented to allow Celestrium to interact with its data source properly.

#### `getLinks(node, nodes, callback)`

* `node` is a single node in the graph
* `nodes` is a list of nodes in the graph
* `callback` is a function which should be called with an array of links, `A`, st. `A[i]` is the link from `node` to `nodes[i]`.
  * A link should be a javascript object with a `strength` attribute in `[0,1]` and can optionally have a `direction` attribute in `{forward, backward, bidrectional}` indicating the directionality of that link.

#### `getLinkedNodes(nodes, callback)`

* `nodes` is a an array of nodes
* `callback` is a function which should be called with an array of `nodes` which are linked to any node in `nodes`.

Note that both of these functions accept existing nodes as arguments - so where does the first node come from?
A function such as `getAllNodes` is computationally infeasible for some datasets, so to not limit Celestrium to data sets which can be completely enumerated, it was left out of the DataProvider specification.
For data sets that can accomplish this, the NodeSearch plugin allows lookup of a node by name.
For data sets that cannot accomplish this, it is left to the developer to provide some form of random access to its nodes.

## Three Interface Implementations

This section provides concrete examples of interfaces using Celestrium.
The first is an interface which has no backend - it simply produces random links between nodes named after the Phonetic Alphabet.
This random interface is then used as a baseline in comparison to implementations of three real data sets.
Because some data sets generate their graphs differently i.e. sparse matrices vs. redirecting to a REST API vs. static data, only the main script and data provider scripts are compared, however other scripts which were necessary for each interface to function are described in each section for reference.

### Baseline - Random

This example shows the necessary code to create the functionality for a random graph generator.
This implementation is also more thoroughly explained to illustrate the general structure of an implementation.

> NOTE: `PhoneticAlphabet` is just an array of strings which is the phonetic alphabet.

#### `main.coffee`

```coffeescript
requirejs.config {baseUrl: "/js"}

require ["Celestrium", "PhoneticAlphabet"],
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
    "RandomDataProvider": {}

  Celestrium.init plugins
```

This script is the entry point for code execution.

First, it configures the location where requirejs finds its modules.

Then `require` is used to load the `Celestrium` module definition and initiate the desired plugins for this interface.
`Celestrium.init` expects a dictionary with keys as the `requirejs` path to the plugin to be instantiated and values as the object to be fed as an argument to that plugin's constructor, as described in the Implementation Section.

#### `RandomDataProvider.coffee`

```coffeescript
define ["DataProvider", "PhoneticAlphabet"],
(DataProvider, PhoneticAlphabet) ->
  class RandomDataProvider extends DataProvider

    getLinks: (node, nodes, callback) ->
      callback _.map nodes, () ->
        "strength": Math.max(0, 2 * Math.random() - 1)
        "direction": _.sample [
          null,
          "forward",
          "backward",
          "bidirectional"
        ]

    getLinkedNodes: (nodes, callback) ->
      callback _.chain(PhoneticAlphabet)
        .sample(5)
        .map((word) -> {"text": word})
        .value()
```

As described in the implementation section, `getLinks` returns an array of links between `node` and `nodes`.
In this case, it's 0 half the time and randomly between [0,1] the other half.
It's directionality is also random.

`getLinkedNodes` returns all nodes linked to any node in `nodes`, which in this case is 5 random entries from the Phonetic Alphabet.

And that's it! The resulting interface can be seen in the Example Interface section above.

### Interface 1/3 - Emails

The first data set that we built an interface for using Celestrium was an email dataset. This takes raw email data in json format and represents email users and lists as nodes, and flow of email as directed edges. The thicker an edge is, the more heavy the flow of emails between the two users is. An edge has a single direction if all the emails between two nodes are in one direction. An edge is bidirectional if there has been email communication in both directions between the two nodes.

This analysis brought about some interesting results. There are many email lists that are always only on the receiving end of emails (such as `vball`) - being able to visually analyze the dataset made this fact very obvious. Also, using the Celestrium link strength chooser allowed us to see which relationships were more email-heavy than others.

![image](https://f.cloud.github.com/assets/1238874/1699336/b163b194-5f92-11e3-9e97-023cd398f5c3.png)

### `main.coffee`
This is a standard implementation of the main entry-point to Celestrium.
In this implementation, we define an ordering for our plugins based on what we think will allow for the best usability in exploring this dataset.

```coffeescript
requirejs.config
  baseUrl: "/scripts/celestrium/core/"

  paths:
    local: "../../"

require ["Celestrium"], (Celestrium) ->

  plugins =

    Layout:
      el: document.querySelector("body")

    KeyListener:
      document.querySelector("body")

    GraphModel:
      nodeHash: (node) -> node.text
      linkHash: (link) -> link.source.text + link.target.text

    GraphView: {}
    Sliders: {}
    ForceSliders:
      pluginOrder: 2
    NodeSearch:
      pluginOrder: 1
      prefetch: "get_nodes"

    Stats:
      pluginOrder: 2
    NodeSelection: {}
    LinkDistribution:
      pluginOrder: 3
    SelectionLayer: {}
    "local/EmailDataProvider": {}

  Celestrium.init plugins, (instances) ->
    instances["GraphView"].getLinkFilter().set("threshold", 0)
```

### `EmailDataProvider.coffee`
This is a very simple example of a DataProvider implementation that communicates with a backend server. `EmailDataProvider` hits the server with an ajax request and processes the returned data so that Celestrium can render it.

```coffeescript
define ["DataProvider"], (DataProvider) ->

  class EmailDataProvider extends DataProvider

    init: (instances) ->
      super(instances)

    getLinks: (node, nodes, callback) ->
      data =
        node: JSON.stringify(node)
        otherNodes: JSON.stringify(nodes)
      @ajax "get_edges", data, (links) ->
        callback links

    getLinkedNodes: (nodes, callback) ->
      data =
        nodes: JSON.stringify(nodes)
      @ajax "get_related_nodes", data, callback
```

<!-- The most unique thing about the emails dataset is that emails have directions. For this reason, we developed Celestrium to support directed edges.
We can see that between many pairs of users, the communication is one-sided many times.
Celestrium supports directed edges, so it is very simple for a developer to provide 'directed-ness' in their graphs.

In implementing this, first a python script was written to clean raw data into json for the server to read. The server then digests all the emails and organizes them into a hashtable for easy access. -->

#### Review of Celstrium


In building this emails visualization, it was apparent how easy Celestrium made it to build a frontend from raw json data. The ease in defining link strengths also made it very flexible for us to try different ways to represent links, to see which led to the most effective visualization.

One of the key features that came out of this dataset was the directed edges property. Since a prominent property of an email is the direction of the email (who sends it and who receives it), it is natural to want to show that directedness in the visualization. From this need, we allowed edges to have a direction property from the following possiblities: `{bidirectional, forward, backward}`.

As we were developing this interface, we started realizing how cluttered the UI was. We added more and more plugins, which placed more and more boxes on the screen in various corners. We also realized that there were some plugins, such as the Dimensionality Slider that were not necessary to the emails dataset. To counter this issue, we built a plugins container that made it very customizable and easy for the developer to dictate which plugins would be included, and even what order they would be. We also allowed the plugins to be collapsed so the user could focus solely on the graph at hand.

Currently, this dataset comes from raw static json data. It would be neat if Celestrium could handle changes in the server dynamically, and the backend was hooked up to a real email inbox. The existing implementation only shows an update to the graph if the user makes another request that includes the update. Future work in this would perhaps involve considering long-polling or sockets to show updates from the backend, live. This and other dynamically changing datasets would be expressed much more gracefully if that were the case.

Overall, creating this interface gave us a very clear idea of what was necessary to make this a strong, flexible, and usable library for all kinds of graphs - it also gave us an idea of what our next steps are to make Celestrium even more versatile.

### Interface 2/3 - Github Collaboration

The Github dataset shows collaboration between users on Github; the higher the link strength between 2 users, the more public repos they have collaborated on together.
First a python script was written to scrape the Github API and collect data on users and their collaboratores into a JSON format.
A GithubProvider class was then written to provide the get_nodes function required in the Node Search plugin, and the get_links and get_related_nodes functions required in the DataProvider.


![image](https://f.cloud.github.com/assets/774269/1699263/f6d3cd38-5f8b-11e3-990c-15a56594ea29.png)

Looking at the distribution of collaborations, there were many relationships with few repos collaborated on, with some outliers of a very high number of repos collaborated on.
This distribution inspired a LinkDistributionNormalizer plugin, where link strengths could be transformed linearly, logarithmically, or into percentiles to best fit the distribution of the data.

#### `main.coffee`

```coffeescript
requirejs.config

  baseUrl: "/celestrium/core/"

  paths:
    local: "../../"

require ["Celestrium"], (Celestrium) ->
  plugins =
    Layout:
      el: document.querySelector("body")

    KeyListener:
      document.querySelector("body")

    GraphModel:
      nodeHash: (node) -> node.text
      linkHash: (link) -> link.source.text + link.target.text

    GraphView: {}

    "Sliders": {}
    "ForceSliders": {}
    "NodeSearch":
        prefetch: "get_nodes"
      "Stats": {}
      "NodeSelection": {}
      "SelectionLayer": {}
      "NodeDetails": {}
      "LinkDistribution": {}
      "LinkDistributionNormalizer": {}

    "local/GithubDataProvider": {}

  # initialize the plugins and execute a callback once done
  Celestrium.init plugins, (instances) ->

    # this allows all link strengths to be visible
    instances["GraphView"].getLinkFilter().set("threshold", 0)

```

#### `GithubDataProvider.coffee`

```coffeescript
define ["DataProvider"], (DataProvider) ->

  class GithubDataProvider extends DataProvider

    init: (instances) ->
      super(instances)


    getLinks: (node, nodes, callback) ->
      data =
        node: JSON.stringify(node)
        otherNodes: JSON.stringify(nodes)
      @ajax "get_edges", data, (arrayOfCoeffs) ->
        callback _.map arrayOfCoeffs, (coeffs, i) ->
          strength: coeffs
          base_value: coeffs

    getLinkedNodes: (nodes, callback) ->
      data =
        nodes: JSON.stringify(nodes)
      @ajax "get_related_nodes", data, callback
```

#### Future Work

The goal of this dataset is to show collaboration relationships on Github.  However, only publicly available data could be used, which restricts this to public repos.
In addition, the measure of link strength is arbitrary; I used the number of repos they collaborated on.  But should collaboration on a project with a few other people be counted the same as collaboration on a project with hundreds of other users?
The metric for 'collaboration strength' could certainly be improved on.

Future work would also include connecting the Celestrium DataProvider endpoints to query the live Github API, not needing to download a static version of data.


#### Review


The work to implement the functions required by Celestrium (DataProvider and NodeSearch plugins) was straightforward for this dataset.
In scraping the Github API, we kept in mind it would be used for Celestrium, so we purposely grabbed only the neccessary data for this project.
In the real world, a data cleaning step would most likely be needed on an existing dataset.
Overall however, any graph-like dataset should have concepts of nodes and edges at their core, so it would be a very similar process.

Customizing which plugins to use in the main script generally worked well, needing simply to add a line with the plugin's name.  However, some plugins had dependencies on others and therefore needed to be listed in certain orders (ex. GraphModel before GraphView).This requires the developer to have some understanding of how Celestrium works, or debug it if they list plugins in a wrong order.

Overall, I found Celestrium to have a quick setup time going from having a dataset to seeing it visualized.  The plugin architecture is very good at presenting modular components for developers to understand and then customize their visualization.

### Interface 3/3 - Semantic Networks

The third data set that we built an interface for using Celestrium was a semantic network.
More specifically, it was showing the results of performing **inference** over a semantic network (this is more well defined later.)
Nodes represented every day concepts and the links showed closely they were inferred to be semantically related.

#### Example of Semantic Network Interface

![image](https://f.cloud.github.com/assets/1418690/1689464/df3411e8-5e22-11e3-8477-683173eb9d24.png)

#### Main Script
```coffeescript
localStorage.clear()
requirejs.config

  # must point to the URL corresponding to the celestrium repo
  baseUrl: "/scripts/celestrium/core"
  # specifies namespace and URL path to my custom plugins
  paths: "uap": "../../uap/"

# main entry point
require ["Celestrium"], (Celestrium) ->

  # call with server's response to ping about dimensionality
  main = (response) ->

    # initialize the workspace with all the below plugins
    Celestrium.init
      # these come with celestrium
      # their arguments should be specific to this data set
      "Layout":
        "el": document.querySelector "#workspace"
        "title": "UAP"
      "KeyListener":
        document.querySelector "body"
      "GraphModel":
        "nodeHash": (node) -> node.text
        "linkHash": (link) -> link.source.text + link.target.text
      "GraphView": {}
      "Sliders": {}
      "ForceSliders": {}
      "NodeSearch":
        prefetch: "get_nodes"
      "Stats": {}
      "NodeSelection": {}
      "SelectionLayer": {}
      "NodeDetails": {}
      "LinkDistribution": {}
      # these are plugins i defined specific to this data set
      "uap/DimSlider":
        [response.min, response.max]
      "uap/ConceptProvider": {}
      "uap/CodeLinks": {}

  # ask server for range of dimensionalities
  $.ajax
    url: "get_dimensionality_bounds"
    success: main
```

#### `DataProvider` Implementation

```coffeescript
# interface to uap's semantic network
# nodes are concepts from a semantic network
# links are the relatedness of two concepts
define ["DataProvider"], (DataProvider) ->

  # minStrength is the minimum similarity
  # two nodes must have to be considered linked.
  # this is evaluated at the minimum dimensionality
  numNodes = 25

  class ConceptProvider extends DataProvider

    init: (instances) ->
      @dimSlider = instances["uap/DimSlider"]
      super(instances)

    getLinks: (node, nodes, callback) ->
      data =
        node: JSON.stringify(node)
        otherNodes: JSON.stringify(nodes)
      @ajax "get_edges", data, (arrayOfCoeffs) ->
        callback _.map arrayOfCoeffs, (coeffs, i) ->
          coeffs: coeffs

    getLinkedNodes: (nodes, callback) ->
      data =
        nodes: JSON.stringify(nodes)
        numNodes: numNodes
      @ajax "get_related_nodes", data, callback

    # initialize each link's strength before being added to the graph model
    linkFilter: (link) ->
      @dimSlider.setLinkStrength(link)
      return true
```

The most interesting part of this implementation is that `ConceptProvider` doesn't define a link's strength, only a `coeffs` parameter, then it uses `DimSlider`'s `setLinkString` function as a filter on the link.
This because the link strength's are actually a function of a polynomial in the **dimensionality** of the inference process, whose value is maintained in `DimSlider`.
So on the server, each link's polynomial is constructed rather than a single value, the coefficients are sent to `DataProvider`, then `DimSlider` uses the current value of the "Dimensionality Slider" in the interface (see the example picture) to actually define the link's strength numerically.
Therefore, when the slider is adjusted in the interface, the link strengths are changed and visualized in realtime.

#### Review of Celestrium

Celestrium's flexibility in defining the strength of a link was critical in creating this interface.
This interface also prompted the design of the `linkFilter` feature in DataProvider, allowing the strength of the link to be defined with respect to the current state of the client interface.
Additionally, this extra slider inspired the creation of the `Sliders` plugin, and allows this "Dimensionality Slider" to integrate seemlessly into the UI next to the other sliders.

Another critical part of this interface is that adjusting the "Dimensionality Slider" updates the graph in real time.
This was made by possible and actually straightforward through Celestrium's design.
GraphView listens for changes to GraphModel and automatically updates itself.
This made it very straightforward to update the graph because all that was needed was to modify the underlying GraphModel and the interface updated itself without any extra effort specific to this data set.

Future work in this interface would be to include different types of nodes, which is something that Celestrium currently doesn't prohibit, but doesn't provide express functionality for.
So, perhaps a next step is to provide functionality that supports having distinct types of nodes.
More details of the specific needs of this dataset should be investigated before deciding on the specific features this would entail.

In summary, creating this interface definitely helped evolve several features of Celestrium and validated several aspects of its design as well.
It was found to be found to be very easy to establish the frontend for this data set, which is ultimately the goal of Celestrium.

## Suggested Future Work

Now that we've seen what Celestrium can do, it is worth detailing it's limitations and ideas for new functionality, the subjects of the following sections.
Future contributors to Celestrium are encouraged to address these topics.

###  Current Limitations

> These are limitations of the current implementations.
> Reducing these limitations is an easy way to get at future work.
> I leave *new* features to @haosharon in the next section.

Celestrium's design and implementation are certainly not without fault.
Because Celestrium's efficacy is based on how easy it is for developers to use, issues of various scopes come into play.
In an effort to explain the full spectrum, we now detail these issues progressing from the purely logistical to the more technical.

#### Infrastructure

While not as intellectually stimulating as other problems, Celestrium's infrastructure could perhaps be improved in the following ways.

Firstly, Celestrium is written primarily in Coffeescript, which compiles to Javascript.
Because of this, any developer using Celestrium must bring the tools to do this compilation into their project when they might not necessarily want or be able to.
Looking into using requirejs's optimization tool on the compiled output, Celestrium could potentially release a minified, single javascript file, making it much easier to simply put in a project.

Additionally, Celestrium uses Less, which compiles to CSS. Currently, Celestrium avoids the need to compile its less files but at the cost of users of celestrium needing to load the Less compiler onto any webpage using Celestrium.
A similar, compiled version of the CSS should be made available for Celestrium as well.

#### Code Organization

Moving into how Celestrium organizes its modules, several things could be improved.

As mentinoed previously, circular dependencies amongst plugins are not allowed.
The only drawback as it stands is that plugins must be specified according the their partial ordering of depedencies in calling `Celestrium.init`.
It remains to be seen if there is a good use case which would merit this or if there is a complete argument against circular dependencies.
Either allowing circular dependencies or providing a more thorough argument against them would at least clarify the appropriateness of this decision.

Additionally, the Layout plugin, while convenenient, is not as configurable as it could perhaps be.
While this isn't problematic in isolation, it is problematic that many of the other plugins rely on using Layout, because not wanting to use Layout then implies one cannot use any plugins which depends on it.
Making Layout more configurable and/or removing other plugins' dependence on it would certainly make Celestrium more modular.

#### Scalability

How large of a graph can interfaces created by Celestrium handle?
This question is open to interpretation, so first some framing is in order.

Firstly, we consider the scalability of the backend database a separate issue.
Celestrium is an entirely frontend library, so the specifics of the database performance certainly affect its use in practice, but it is not fundamentally part of Celestrium and so is not a good metric by which to judge Celestrium's performance.

Therefore, we will focus on the performance of the frontend.
This was done by measuring certain metrics for rendering different numbers of nodes and links, all populated entirely within the frontend.
Tests were performed on a 15" MacBook Pro with Retina Display, 2.6 GHz Intel Core i7 with 8 GB 1600 MHz DDR3 RAM using Goolge Chrome 31.0.1650.57.
Specifically, nine different tests were conducted where the number of nodes and links were from {1000, 2500, 5000}.
Then the following metrics were evaluated and tabulated.

* **Memory Usage** - The amount of memory used by the tab in Chrome
* **Time to Populate the Graph** - The amount of time it took to add the specified number of nodes and links to the graph.
* **Responsiveness of the Visualization** - Once the graph was completely populated, d3's force directed layouts iterates and on each **tick**, the graph updates the location of the nodes and links. To measure the responsiveness, the amount of time between ticks for the first ten seconds of the rendering was averaged.

Before going into the details of the results, it is worth noting that while the interface can handle these sizes of graphs, it is not a typical use case.
The purpose of these interfaces is for a human to explore these graphs and a human would have a hard time understanding a graph of even 1000 nodes and links.
Testing on a more reasonable scale i.e. 100 nodes and 1000 links yielded very good performance.
We found ~24 ms/tick which equates to ~40 updates per second, which is high enough to produce very fluid rendering of the graph to the user.
The memory usage was negligble and it took less than one second to populate the graph.
In summary, at scales a human could understand, Celestrium has been found to perform very well.

The purpose of explaining the following metrics, then, is to understand the limits of Celestrium's interface, human capabilities aside.
These limitations are worth nothing and improving because they could help improve performance on slower machines which may have trouble even on more reasonably sized graphs.
Additionally, it is impossible to rule out a use case where these sized graphs are actually necessary to render.
With that in mind, let's start with the memory used in each test case.

##### Memory Usage

The amount of memory used by the tab in chrome according to Chrome's Task Manager was recorded and the following results were found.

![image](https://f.cloud.github.com/assets/1418690/1689050/6139b0ec-5e16-11e3-9221-b234726e33f4.png)

To summarize, the amount of memory certainly scales with both links and nodes, but it seems to grow much more with the number of nodes.
The absolute scale of these numbers is well within the acceptable range of memory usage.
For reference, a tab with Gmail open was using 170 MB, putting the highest memory used by Celestrium at less than 65% of Gmail.

##### Time to Populate the Graph

Taking the time to simply populate the graph seemed to result in more dubious results for Celestrium.

To explain the following three charts, the first shows just the time it took to add the nodes to the graph for each test.
The second shows just the time it took to add the links to the graph.
The third then shows the total time, which is the sum of the first two.

![image](https://f.cloud.github.com/assets/1418690/1689134/a544cf72-5e18-11e3-987e-a1910a7a5836.png)

A few things are notable here.

The first is the general range of the results. The fastest test took approximately 6 seconds while the slowest took 4 **minutes**.

The second is that the time to add a certain number of nodes was irrespective of the number of links, while the opposite is not true and the reason for this is perhaps somewhat subtle - the nodes were always added first.
Link objects must reference the actual node objects they are linking, so the nodes must be created first.
The number of links added will never affect the time to load the nodes because it occurs after the noads are loaded.
However, it is somewhat unclear why the number of nodes affects the time to add a link.
We hypothesize that this is due to the overlap in the process of adding the links and the events still being fired from adding the nodes.

And lastly, the performance in loading the graph seems to follow the results of memory usage in that the number of nodes seems to have a greater impact on the time than the number of links.

How could this be improved?
Perhaps the fundamental issue is that nodes and links must be added individually rather than all at once.
This design choice was made to more easily communicate with the backend about updating the state of the graph.
In particular, when adding a node to the graph, the only links that must be fetched to keep the grpah current are between that node and all the nodes currently present.
If more than one node is added a time, the links between each pair of nodes within that new group must now also be considered, greatly increasing the complexity the developer must deal with.
However, if high performance for larger graphs and/or slower machines is required, we feel this is the largest bottleneck.

##### Visualization Responsiveness

The last metric to consider is how quickly the force directed layout updates itself.

It is worth mentioning the algorithm that d3 implements is the [Barnes-Hut approximation](http://en.wikipedia.org/wiki/Barnes%E2%80%93Hut_simulation) which provides an asymptotic runtime of `O(n*log(n))` for `n` nodes, as opposed to a naive implementation's `O(n^2))`.

Additionally, the rendering speed is improved if the visualization is zoomed out and worsened when zoomed in.
For these tests, the default zoom level was used for uniformity.

The following metrics were found by, once the graph was completely loaded, averaging the time between updates of the layout for the first ten seconds of the simulation.
Here is what was found:

![image](https://f.cloud.github.com/assets/1418690/1689232/a233a468-5e1b-11e3-9801-196c8c156c91.png)

First, it seems there is a fair amount of variability, as the results go from 1785 ms for 2500 nodes and links to 841 ms when the number of links *increases* to 5000.
A possible reason for this is that, due to the large number of nodes, some nodes were not always visible on the screen, perhaps reducing the browser's rendering computation.
Perhaps in the case with 2500 nodes and 5000 links, more nodes than usual were not visible, speeding up the runtime of those iterations.

To explain the >10000 entry, using 5000 nodes and links resulted in the layout never completing it's second iteration in the first ten seconds.

In summary, it seems Celestrium's interface can definitely become unusable when scaled up these sized graphs.
To overcome this, one could leverage the effects of zooming and when slow layout iterations are detected, zoom out.
Additionally, a force directed layout aproach may fundamentally not be feasable at this scale, so a one time static layout algorithm may be necessary at this scale.
Or, one could run the layout internally without updating the UI, then simply render the final result of the layout process at the end.
Again, because humans most likely would not be able to make sense of so much data, making this interface usable at this scale may not be a priority, but we suggest at least detecting when the layout iterations become slow and handling it accordingly so the user is not left simply staring at a faltering visualization.

### General Future Work

For the future, there are many features we'd like to add.

* **Minimap** when a user explores a very large dataset, it is sometimes easy to get lost in the low-level details. We'd like to provide a minimap so users can always have a sense of the entire graph.

* **Clustering** Celestrium currently uses D3's force-directed layout. It would be nice to be able to define some clustering/grouping of nodes, perhaps through positioning or drawing a shape around the group.

* **Alternate Layouts** In addition to clustering, there are many other D3 layouts that we could potentially use. (Grid, linear, hierarchical, etc)

* **Dynamically update graph** Currently, updates from the server only show when we make another request. If we could use some polling functionality, or perhaps sockets, we could dynamically show changes from the server.

* **Interactive tutorial** Since Celestrium provides a lot of plugins and features, it would be nice if we could provide an interactive tutorial for the user to get started using Celestrium to analyze datasets. There are many libraries available to do this, such as [`intro.js`](http://usablica.github.io/intro.js/).

* **Serialization and caching** On every addition to the graph, we make a request to the server. In efforts to optimize performance, we could use Javascript's `localStorage` or `sessionStorage` to make this happen.

* **Custom mapping to visual dimensions** When nodes or edges have continuous values, we want to allow the user to specify how that should be represented. Currently, we use histograms to bin link strengths. However, it could be possible that the developer can define their own views to display values and attributes of the nodes and links.

* **Graph analysis** Since we have such a well formed graph, it seems natural to be able to perform graph analysis on our data. It would be useful to have plugins for different analyses such as PageRank, shortest path, and different search algorithms.

* **Writeable Graph** Currently, our implementation is read-only. A huge feature would be to allow users to edit the graph. This would be a huge task to undertake, but would be great for users that see the need to build graphs interactively.

* **Unit Testing and Continuous Integration** We'd like to make it easy to test our separate plugins. It'd be nice to have a testing framework so that when we develop for Celestrium and contribute through pull requests, we can ensure their robustness through automatic unit tests.

* **Semantic Versioning** In addition to unit testing and continuous integration, we'd like to make Celestrium easy to develop from by declaring v1.0.0 pursuant to [semantic versioning](http://semver.org/).

## Conclusion

Celestrium was created out of the desire to reduce the activation energy in creating graph visualization and exploration tools for a variety of different data sets.
To that end, it created it's own plugin architecture and plugins to allow interfaces to be created with only the desired components.
In using Celestrium for different data sets, it was found that it was general enough to handle each of them and provide meaningful interfaces.
However, their definitely remain opportunities for future work to improve Celestrium, ranging from logistical improvements to more technical subjects.
Ultimately, we feel we have created a very practical tool that can be immediately put to use.
