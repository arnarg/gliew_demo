import gleam/int
import gleam/option.{None, Some}
import gleam/erlang/process
import nakai/html
import nakai/html/attrs
import gliew
import gliew_demo/service/monitor.{Monitor}

pub type MetricsContext {
  MetricsContext(monitor: Monitor)
}

pub fn metrics(context: MetricsContext) {
  use assign <- gliew.live_mount(init_metrics, with: context)

  let #(cpu, mem) = case assign {
    Some(data) -> #(data.cpu, data.mem)
    None -> #(0, 0)
  }

  html.div(
    [gliew.morph(), attrs.class("monitors")],
    [
      html.div(
        [attrs.class("monitor-container")],
        [html.div_text([attrs.class("monitor-label")], "CPU"), bar(cpu)],
      ),
      html.div(
        [attrs.class("monitor-container")],
        [html.div_text([attrs.class("monitor-label")], "MEM"), bar(mem)],
      ),
    ],
  )
}

fn bar(percent: Int) {
  html.div(
    [attrs.class("monitor-meter")],
    [
      html.div(
        [
          attrs.class("status"),
          attrs.style("width: " <> int.to_string(percent) <> "%"),
        ],
        [],
      ),
    ],
  )
}

fn init_metrics(context: MetricsContext) {
  // Create a new subject to subscribe to
  let subject = process.new_subject()

  // Subscribe to monitor
  monitor.subscribe(context.monitor, subject)

  subject
}
