export page, row, cell

"""
    `function page(elemid, args...; partial::Bool = false, title::String = "", class::String = "", style::String = "",
                    channel::String = Genie.config.webchannels_default_route , head_content::String = "", kwargs...)`

Generates the HTML code corresponding to an SPA (a single page application), defining the root element of the Vue app.

### Example

```julia
julia> page(:elemid, [
        span("Hello", @text(:greeting))
        ])
"<!DOCTYPE html>\n<html><head><title></title><meta name=\"viewport\" content=\"width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, minimal-ui\" /></head><body class style><link href=\"https://fonts.googleapis.com/css?family=Material+Icons\" rel=\"stylesheet\" /><link href=\"https://fonts.googleapis.com/css2?family=Lato:ital,wght@0,400;0,700;0,900;1,400&display=swap\" rel=\"stylesheet\" /><link href=\"/css/stipple/stipplecore.min.css\" rel=\"stylesheet\" /><link href=\"/css/stipple/quasar.min.css\" rel=\"stylesheet\" /><div id=elemid><span v-text='greeting'>Hello</span></div><script src=\"/js/channels.js?v=1.17.1\"></script><script src=\"/js/stipple/underscore-min.js\"></script><script src=\"/js/stipple/vue.js\"></script><script src=\"/js/stipple/quasar.umd.min.js\"></script>\n<script src=\"/js/stipple/apexcharts.min.js\"></script><script src=\"/js/stipple/vue-apexcharts.min.js\"></script><script src=\"/js/stipple/stipplecore.js\" defer></script><script src=\"/js/stipple/vue_filters.js\" defer></script></body></html>"
```
"""
function page(elemid, args...; partial::Bool = false, title::String = "", class::String = "", style::String = "",
              channel::String = Genie.config.webchannels_default_route , head_content::String = "", core_theme::Bool = true,
              kwargs...)
  Stipple.Layout.layout(Genie.Renderer.Html.div(id = elemid, args...; class = class, kwargs...), partial = partial, title = title,
                        style = style, head_content = head_content, channel = channel, core_theme = core_theme)
end

"""
    `function row(args...; kwargs...)`

Creates a `div` HTML element with a CSS class named `row`. This works with Stipple's Twitter Bootstrap to create the
responsive CSS grid of the web page. The `row` function creates rows which should include `cell`s.

### Example

```julia
julia> row(span("Hello"))
"<div class=\"row\"><span>Hello</span></div>"
```
"""
function row(args...; kwargs...)
  kwargs = NamedTuple(Dict{Symbol,Any}(kwargs...), :class, "row")

  Genie.Renderer.Html.div(args...; kwargs...)
end

"""
    `function cell(args...; size::Int=0, kwargs...)`

Creates a `div` HTML element with CSS classes named `col col-12` and `col-sm-$size`.
This works with Stipple's Twitter Bootstrap to create the responsive CSS grid of the web page. The `cell`s should be
included within `row`s.

### Example

```julia
julia> row(cell(size=2, span("Hello")))
"<div class=\"row\"><div class=\"col col-12 col-sm-2\"><span>Hello</span></div></div>"
```
"""
function cell(args...; size::Int=0, kwargs...)
  kwargs = NamedTuple(Dict{Symbol,Any}(kwargs...), :class, "col col-12 col-sm$(size > 0 ? "-$size" : "")")

  Genie.Renderer.Html.div(args...; kwargs...)
end
