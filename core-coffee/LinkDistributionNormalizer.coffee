 # provides details of the selected nodes
define [], () ->

	class LinkDistributionNormalizer extends Backbone.View
		init: (instances) ->
			@graphModel = instances["GraphModel"]

			instances["Layout"].addMiddleLeft @el
			@render()


		@sortNumber: (a,b) ->
					return a - b

		render: ->
			model = @graphModel
			links = @graphModel.getLinks()
			$container = $("<div />").addClass("link-normalizer-container")
			$header = $("<h3 />").text("Normalize Distribution")
			$input = $("<select id=\"selectId\" name=\"selectName\" />")
			$container.append $header
			$container.append $input


			options = ["Original Values", "Linear", "Logarithmic Base 10", "Logarithmic Base 2" , "Percentile"]
			for option in options
				$option = $("<option value=\"" + option + "\"/>").text(option)
				$input.append $option
			@$el.append $container

			normalize = @normalize
			$input.on "change", () ->
				transformation = $('#selectId :selected').text()
				normalize(transformation,links)
				model.trigger "change:links"
				model.trigger "change"

		normalize: (transformation,links) ->
			weights = ((Number) l.base_value for l in links)
			max_weight = Math.max.apply Math,weights
			min_weight = Math.min.apply Math,weights

			if transformation == "Logarithmic Base 10"
				#logScale = d3.scale.log().domain([0,max]).range([0, 1])
				for link in links
					link.strength = ((Math.log link.base_value) / (Math.LN10) ) / ((Math.log max_weight) / (Math.LN10))

			if transformation == "Logarithmic Base 2"
				for link in links
					link.strength = (Math.log link.base_value) / (Math.log max_weight)

			if transformation == "Linear"
				for link in links
					link.strength = (link.base_value - min_weight) / (max_weight - min_weight)

			if transformation == "Percentile"
				weights.sort(LinkDistributionNormalizer.sortNumber)
				for link in links
					link.strength = ((weights.indexOf link.base_value) + (weights.lastIndexOf link.base_value)/ 2) / weights.length

			if transformation == "Original Values"
				for link in links
					link.strength = link.base_value

			return this


