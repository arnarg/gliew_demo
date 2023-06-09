import gleam/int
import gleam/float
import gleam/list
import gleam/function
import gleam/option.{None, Some}
import gleam/dynamic.{Dynamic}
import gleam/result
import gleam/otp/actor
import gleam/erlang
import gleam/erlang/atom
import gleam/erlang/process.{Subject}
import nakai/html
import nakai/html/attrs
import gliew
import gliew_demo/component/logs.{Message as LoggerMessage}

pub type MetricsContext {
  MetricsContext(monitor: Subject(Message))
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
  process.send(context.monitor, Subscribe(subject))

  subject
}

// Monitoring actor --------------------------------------------

fn start_os_mon() {
  erlang.ensure_all_started(atom.create_from_string("os_mon"))
}

external fn get_cpu_util() -> Float =
  "cpu_sup" "util"

external fn get_mem_data() -> #(Int, Int, Dynamic) =
  "memsup" "get_memory_data"

pub type MonitorStatus {
  MonitorStatus(cpu: Int, mem: Int)
}

pub opaque type Message {
  Update
  Subscribe(subject: Subject(MonitorStatus))
}

type State {
  State(
    self: Subject(Message),
    interval: Int,
    subscribers: List(Subject(MonitorStatus)),
  )
}

pub fn start_monitor(interval: Int) {
  actor.start_spec(actor.Spec(
    init: fn() {
      // Ensure os_mon is started
      let _ = start_os_mon()

      // Create a subject for ourselves
      let self = process.new_subject()

      // Select our own messages
      let selector =
        process.new_selector()
        |> process.selecting(self, function.identity)

      // Send the initial update message
      let _ = process.send_after(self, interval, Update)

      // Actor ready
      actor.Ready(State(self, interval, []), selector)
    },
    init_timeout: 1000,
    loop: loop,
  ))
}

fn loop(msg: Message, state: State) {
  case msg {
    Update -> {
      // Get CPU utilization
      let cpu =
        get_cpu_util()
        |> float.round

      // Get memory utilization
      let mem_data = get_mem_data()
      let mem = calc_mem(mem_data.0, mem_data.1)

      // Send to all and filter list of dead subscribers
      let new_subs = send_to_all(MonitorStatus(cpu, mem), state.subscribers)

      // Send an update message to ourseleves after interval
      let _ = process.send_after(state.self, state.interval, Update)

      actor.Continue(State(..state, subscribers: new_subs))
    }
    Subscribe(subject) -> {
      // Continue actor with new subject subscribed
      actor.Continue(
        State(
          ..state,
          subscribers: state.subscribers
          |> list.prepend(subject),
        ),
      )
    }
  }
}

fn calc_mem(total: Int, alloc: Int) {
  float.divide(int.to_float(total), int.to_float(alloc))
  |> result.then(fn(r) { Ok(float.multiply(r, 10.0)) })
  |> result.map(float.round)
  |> result.unwrap(0)
}

fn send_to_all(status: MonitorStatus, subscribers: List(Subject(MonitorStatus))) {
  case subscribers {
    [] -> subscribers
    [next, ..rest] ->
      case
        process.is_alive(
          next
          |> process.subject_owner,
        )
      {
        True -> {
          process.send(next, status)

          send_to_all(status, rest)
          |> list.prepend(next)
        }
        False -> send_to_all(status, rest)
      }
  }
}
