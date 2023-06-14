import gleam/int
import gleam/float
import gleam/list
import gleam/result
import gleam/dynamic.{Dynamic}
import gleam/function
import gleam/otp/actor
import gleam/erlang
import gleam/erlang/process.{Subject}
import gleam/erlang/atom
import gliew_demo/internal/util.{send_to_all}

/// Subject for the monitor actor.
///
pub type Monitor =
  Subject(Message)

/// Contains current status about memory and
/// cpu.
///
pub type MonitorStatus {
  MonitorStatus(cpu: Int, mem: Int)
}

/// Message that can be sent to the monitor
/// actor.
///
pub opaque type Message {
  Update
  Subscribe(subject: Subject(MonitorStatus))
}

// State for the monitor actor.
//
type State {
  State(
    self: Subject(Message),
    interval: Int,
    subscribers: List(Subject(MonitorStatus)),
  )
}

/// Starts a monitor actor that will send data
/// on CPU and Memory utilization every `interval`
/// seconds.
///
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

// Loop for the monitor actor.
//
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

/// Subscribe to monitor.
///
pub fn subscribe(monitor: Monitor, subscriber: Subject(MonitorStatus)) {
  process.send(monitor, Subscribe(subscriber))
}

// Utils -------------------------------------------------

fn calc_mem(total: Int, alloc: Int) {
  float.divide(int.to_float(total), int.to_float(alloc))
  |> result.then(fn(r) { Ok(float.multiply(r, 10.0)) })
  |> result.map(float.round)
  |> result.unwrap(0)
}

fn start_os_mon() {
  erlang.ensure_all_started(atom.create_from_string("os_mon"))
}

external fn get_cpu_util() -> Float =
  "cpu_sup" "util"

external fn get_mem_data() -> #(Int, Int, Dynamic) =
  "memsup" "get_memory_data"
