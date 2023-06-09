import gleam/erlang/process.{Subject}
import nakai/html
import nakai/html/attrs
import gliew_demo/component/metrics.{Message as MonitorMessage, MetricsContext}
import gliew_demo/component/observer.{
  Message as ObserverMessage, ObserverContext,
}

pub type DashboardContext {
  DashboardContext(
    monitor: Subject(MonitorMessage),
    observer: Subject(ObserverMessage),
  )
}

// Dashboard view
pub fn dashboard(context: DashboardContext) {
  html.div(
    [attrs.class("container")],
    [
      header("gliew observer"),
      metrics(context),
      observer(ObserverContext(context.observer)),
    ],
  )
}

// Header
fn header(text: String) {
  html.div([attrs.class("header")], [html.div_text([], text)])
}

// Metrics section
fn metrics(context: DashboardContext) {
  html.div(
    [attrs.class("metrics")],
    [
      html.div_text([attrs.class("title")], "Server Metrics"),
      metrics.metrics(MetricsContext(context.monitor)),
    ],
  )
}

// Observer section
fn observer(context: ObserverContext) {
  html.div([attrs.class("observer")], [observer.observer(context)])
}
