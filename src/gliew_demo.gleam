import gleam/bit_string
import gleam/result
import gleam/erlang/process
import gleam/erlang/file
import gleam/http.{Get}
import gleam/http/request
import nakai/html
import nakai/html/attrs
import gliew
import gliew_demo/page.{DashboardContext}
import gliew_demo/service/monitor
import gliew_demo/service/observer

fn layout(content: html.Node(a)) -> html.Node(a) {
  html.Html(
    [],
    [
      html.Head([
        html.title("gliew demo"),
        html.link([attrs.rel("stylesheet"), attrs.href("/style.css")]),
        html.meta([
          attrs.name("viewport"),
          attrs.content("width=device-width, initial-scale=1"),
        ]),
        gliew.script(),
        html.Element(tag: "script", attrs: [attrs.src("app.js")], children: []),
      ]),
      html.Body(attrs: [], children: [content]),
    ],
  )
}

pub fn main() {
  let assert Ok(monitor) = monitor.start_monitor(1000)
  let assert Ok(observer) = observer.start_observer(1000)

  let assert Ok(_) =
    gliew.Server(
      port: 8080,
      layout: layout,
      handler: fn(req) {
        case req.method, request.path_segments(req) {
          // Get style.css
          Get, ["style.css"] -> stylesheet()
          // Get app.js
          Get, ["app.js"] -> js("app")
          // Get github.svg
          Get, ["github.svg"] -> svg("github")
          // Get "/"
          Get, [] ->
            page.dashboard(DashboardContext(monitor, observer))
            |> gliew.view(200)
          // Everything else
          _, _ ->
            gliew.response(404)
            |> gliew.with_body("not found")
        }
      },
    )
    |> gliew.serve

  process.sleep_forever()
}

external fn priv_directory(String) -> Result(String, Nil) =
  "gliew_demo_ffi" "priv_directory"

fn stylesheet() {
  let assert Ok(priv) = priv_directory("gliew_demo")
  let assert Ok(css) = file.read_bits(priv <> "/static/style.css")

  gliew.response(200)
  |> gliew.with_body(
    bit_string.to_string(css)
    |> result.unwrap(""),
  )
}

fn svg(name: String) {
  let assert Ok(priv) = priv_directory("gliew_demo")

  case file.read_bits(priv <> "/static/" <> name <> ".svg") {
    Ok(data) ->
      gliew.response(200)
      |> gliew.with_body(
        bit_string.to_string(data)
        |> result.unwrap(""),
      )
    _ ->
      gliew.response(404)
      |> gliew.with_body("not found")
  }
}

fn js(name: String) {
  let assert Ok(priv) = priv_directory("gliew_demo")

  case file.read_bits(priv <> "/static/" <> name <> ".js") {
    Ok(data) ->
      gliew.response(200)
      |> gliew.with_body(
        bit_string.to_string(data)
        |> result.unwrap(""),
      )
    _ ->
      gliew.response(404)
      |> gliew.with_body("not found")
  }
}
