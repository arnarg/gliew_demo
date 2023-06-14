import nakai/html
import nakai/html/attrs
import gliew_demo/service/monitor.{Monitor}
import gliew_demo/service/observer.{Observer} as sobserver
import gliew_demo/component/metrics.{MetricsContext}
import gliew_demo/component/observer.{ObserverContext}

pub type DashboardContext {
  DashboardContext(monitor: Monitor, observer: Observer)
}

// Dashboard view
pub fn dashboard(context: DashboardContext) {
  html.div(
    [attrs.class("container")],
    [
      header("gliew observer"),
      metrics(MetricsContext(context.monitor)),
      observer(ObserverContext(context.observer)),
    ],
  )
}

// Header
fn header(text: String) {
  html.div(
    [attrs.class("header")],
    [
      html.div_text([attrs.class("title")], text),
      html.div(
        [attrs.class("links")],
        [
          html.a(
            [attrs.href("https://github.com/arnarg/gliew_demo")],
            [html.img([attrs.src("/github.svg"), attrs.alt("Github logo")])],
          ),
        ],
      ),
    ],
  )
}

// Metrics section
fn metrics(context: MetricsContext) {
  html.div(
    [attrs.class("metrics")],
    [
      html.div_text([attrs.class("title")], "Server Metrics"),
      metrics.metrics(context),
    ],
  )
}

// Observer section
fn observer(context: ObserverContext) {
  html.div([attrs.class("observer")], [observer.observer(context)])
}
