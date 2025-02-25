"""
# Stipple.Elements

The `Elements` module provides utility methods for interfacing between Julia and Vue.js.
"""
module Elements

import Genie
using Stipple

import Genie.Renderer.Html: HTMLString, normal_element
import JSON.JSONText

export root, elem, vm, @iif, @elsiif, @els, @text, @bind, @data, @on, @showif

#===#

"""
    `function root(app::M)::String where {M<:ReactiveModel}`

Generates a valid JavaScript object name to be used as the name of the Vue app -- and its respective HTML container.
"""
function root(app::M)::String where {M<:ReactiveModel}
  Genie.Generator.validname(typeof(app) |> string)
end

function root(app::Type{M})::String where {M<:ReactiveModel}
  Genie.Generator.validname(app |> string)
end

"""
    `function elem(app::M)::String where {M<:ReactiveModel}`

Generates a JS id `#` reference to the DOM element containing the Vue app template.
"""
function elem(app::M)::String where {M<:ReactiveModel}
  "#$(root(app))"
end

const vm = root

#===#

"""
    `function vue_integration(model::M; vue_app_name::String, endpoint::String, channel::String, debounce::Int)::String where {M<:ReactiveModel}`

Generates the JS/Vue.js code which handles the 2-way data sync between Julia and JavaScript/Vue.js.
It is called internally by `Stipple.init` which allows for the configuration of all the parameters.
"""
function vue_integration(model::M; vue_app_name::String, endpoint::String, channel::String, debounce::Int)::String where {M<:ReactiveModel}
  vue_app = replace(JSON.json(model |> Stipple.render), "\"{" => " {")
  vue_app = replace(vue_app, "}\"" => "} ")

  output =
  string(
    raw"""
    const watcherMixin = {
      methods: {
        $withoutWatchers: function (cb, filter) {
          let ww = (filter === null) ? this._watchers : [];

          if (typeof(filter) == "string") {
            this._watchers.forEach((w) => { if (w.expression == filter) {ww.push(w)} } )
          } else { // if it is a true regex
            this._watchers.forEach((w) => { if (w.expression.match(filter)) {ww.push(w)} } )
          }

          const watchers = ww.map((watcher) => ({ cb: watcher.cb, sync: watcher.sync }));

          for (let index in ww) {
            ww[index].cb = () => null;
            ww[index].sync = true;
          }

          cb();

          for (let index in ww) {
            ww[index].cb = watchers[index].cb;
            ww[index].sync = watchers[index].sync;
          }

        },

        updateField: function (field, newVal) {
          try {
            this.$withoutWatchers(()=>{this[field]=newVal},"function(){return this." + field + "}");
          } catch(ex) {
            console.log(ex);
          }
        }
      }
    }
    const reviveMixin = {
      methods: {
        revive_payload: function(obj) {
          if (typeof obj === 'object') {
            for (var key in obj) {
              if ( (typeof obj[key] === 'object') && (obj[key]!=null) && !(obj[key].jsfunction) ) {
                this.revive_payload(obj[key])
              } else {
                if ( (obj[key]!=null) && (obj[key].jsfunction) ) {
                  obj[key] = Function(obj[key].jsfunction.arguments, obj[key].jsfunction.body)
                  if (key=='stipplejs') { obj[key](); }
                }
              }
            }
          }
          return obj;
        }
      }
    }
    """

    ,

    "\nvar $vue_app_name = new Vue($( replace(vue_app, "\"$(Stipple.UNDEFINED_PLACEHOLDER)\""=>Stipple.UNDEFINED_VALUE) ));\n\n"

    ,

    join([Stipple.watch(vue_app_name, field, channel, debounce, model)
      for field in fieldnames(typeof(model))
      if !(
        !(getfield(model, field) isa Reactive) &&
          ( occursin(Stipple.SETTINGS.readonly_pattern, String(field)) || occursin(Stipple.SETTINGS.private_pattern, String(field)) )  ||
        getfield(model, field) isa Reactive &&
          ( getfield(model, field).r_mode != PUBLIC || getfield(model, field).no_frontend_watcher )
      )
    ])

    ,

    """

  window.parse_payload = function(payload){
    if (payload.key) {
      window.$(vue_app_name).revive_payload(payload)
      window.$(vue_app_name).updateField(payload.key, payload.value);
    }
  }

  window.onload = function() {
    console.log("Loading completed");
    $vue_app_name.\$forceUpdate();
  }
  """
  ) |> repr


  output[2:prevind(output, lastindex(output))]
end

#===#

"""
    `@iif(expr)`

Generates `v-if` Vue.js code using `expr` as the condition.
<https://vuejs.org/v2/api/#v-if>

### Example

```julia
julia> span("Bad stuff's about to happen", class="warning", @iif(:warning))
"<span class=\"warning\" v-if='warning'>Bad stuff's about to happen</span>"
```
"""
macro iif(expr)
  :( "v-if='$($(esc(expr)))'" )
end

"""
    `@elsiif(expr)`

Generates `v-else-if` Vue.js code using `expr` as the condition.
<https://vuejs.org/v2/api/#v-else-if>

### Example

```julia
julia> span("An error has occurred", class="error", @elsiif(:error))
"<span class=\"error\" v-else-if='error'>An error has occurred</span>"
```
"""
macro elsiif(expr)
  :( "v-else-if='$($(esc(expr)))'" )
end

"""
    `@els(expr)`

Generates `v-else` Vue.js code using `expr` as the condition.
<https://vuejs.org/v2/api/#v-else>

### Example

```julia
julia> span("Might want to keep an eye on this", class="notice", @els(:notice))
"<span class=\"notice\" v-else='notice'>Might want to keep an eye on this</span>"
```
"""
macro els(expr)
  :( "v-else='$($(esc(expr)))'" )
end

"""
    `@text(expr)`

Creates a `v-text` or a `text-content.prop` Vue biding to the element's `textContent` property.
<https://vuejs.org/v2/api/#v-text>

### Example

```julia
julia> span("", @text("abc | def"))
"<span :text-content.prop='abc | def'></span>"

julia> span("", @text("abc"))
"<span v-text='abc'></span>"
```
"""
macro text(expr)
  quote
    directive = occursin(" | ", string($(esc(expr)))) ? ":text-content.prop" : "v-text"
    "$(directive)='$($(esc(expr)))'"
  end
end

"""
    `@bind(expr, [type])`

Binds a model parameter to a Vue component, generating a `v-model` property, optionally defining the parameter type.
<https://vuejs.org/v2/api/#v-model>

### Example

```julia
julia> input("", placeholder="Type your name", @bind(:name))
"<input placeholder=\"Type your name\"  v-model='name' />"

julia> input("", placeholder="Type your name", @bind(:name, :identity))
"<input placeholder=\"Type your name\"  v-model.identity='name' />"
```
"""
macro bind(expr)
  :( "v-model='$($(esc(expr)))'" )
end

macro bind(expr, type)
  :( "v-model.$($(esc(type)))='$($(esc(expr)))'" )
end

"""
    `@data(expr)`

Creates a Vue.js data binding for the elements that expect it.

### Example

```julia
julia> plot(@data(:piechart), options! = "plot_options")
"<template><apexchart :options=\"plot_options\" :series=\"piechart\"></apexchart></template>"
```
"""
macro data(expr)
  quote
    x = $(esc(expr))
    if typeof(x) <: Union{AbstractString,Symbol}
      Symbol(x)
    else
      strx = strip("$x")
      startswith(strx, "Any[") && (strx = strx[4:end])

      JSONText(string(":", strx))
    end
  end
end

"""
    `on(action, expr)`

Defines a js routine that is called by the given `action` of the Vue component, e.g. `:click`, `:input`

### Example

```julia
julia> input("", @bind(:input), @on("keyup.enter", "process = true"))
"<input  v-model='input' v-on:keyup.enter='process = true' />"
```
"""
macro on(args, expr)
  :( "v-on:$(string($(esc(args))))='$(replace($(esc(expr)),"'" => raw"\'"))'" )
end

macro showif(expr)
  :( "v-show='$($(esc(expr)))'" )
end

#===#

include(joinpath("elements", "stylesheet.jl"))

end
