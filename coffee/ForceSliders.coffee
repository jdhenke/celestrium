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
