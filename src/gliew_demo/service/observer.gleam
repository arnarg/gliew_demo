import gleam/int
import gleam/list
import gleam/order.{Order}
import gleam/dynamic.{Dynamic}
import gleam/function
import gleam/otp/actor
import gleam/erlang/process.{Pid, Subject}
import gleam/erlang/atom.{Atom}
import gliew_demo/internal/util.{send_to_all}

/// Subject for the observer actor.
///
pub type Observer =
  Subject(Message)

/// Contains current info about a single process.
///
pub type ProcessInfo {
  ProcessInfo(
    pid: Pid,
    memory: Int,
    reductions: Int,
    initial_call: String,
    current_location: String,
  )
}

/// Message that can be sent to the observer
/// actor.
///
pub opaque type Message {
  Update
  Subscribe(subject: Subject(List(ProcessInfo)))
}

// State for the observer actor.
//
type State {
  State(
    self: Subject(Message),
    interval: Int,
    subscribers: List(Subject(List(ProcessInfo))),
  )
}

/// Starts an observer actor that will send
/// data on all processes every `interval`
/// seconds.
///
pub fn start_observer(interval: Int) {
  actor.start_spec(actor.Spec(
    init: fn() {
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

// Loop for the observer actor.
//
fn loop(msg: Message, state: State) {
  case msg {
    Update -> {
      // Get all process data and send to subscribers
      let new_subs =
        get_processes(Sort(ByMemory))
        |> send_to_all(state.subscribers)

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

pub fn subscribe(observer: Observer, subscriber: Subject(List(ProcessInfo))) {
  actor.send(observer, Subscribe(subscriber))
}

// Available data from the erlang `process_info/2` function.
//
type ProcessParam {
  Memory(Int)
  Reductions(Int)
  InitialCall(#(Atom, Atom, Int))
  CurrentLocation(#(Atom, Atom, Int, List(Dynamic)))
}

/// Post processing that should be done on the list of
/// processes.
///
pub type Processor {
  Sort(SortMethod)
  NoProcessor
}

/// What field should be used for sorting.
///
pub type SortMethod {
  ByMemory
  CustomSort(fn(ProcessInfo, ProcessInfo) -> Order)
}

/// Get all processes and process the list using
/// specified method.
///
pub fn get_processes(processor: Processor) -> List(ProcessInfo) {
  processes()
  |> list.map(get_process_info)
  |> do_processing(processor)
}

/// Get process info for a single Pid.
///
fn get_process_info(pid: Pid) -> ProcessInfo {
  let info =
    process_info(
      pid,
      [
        atom.create_from_string("memory"),
        atom.create_from_string("reductions"),
        atom.create_from_string("initial_call"),
        atom.create_from_string("current_location"),
      ],
    )

  case info {
    [
      Memory(memory),
      Reductions(reductions),
      InitialCall(icall),
      CurrentLocation(cloc),
      ..
    ] -> {
      ProcessInfo(
        pid,
        memory,
        reductions,
        icall_to_string(icall),
        cloc_to_string(cloc),
      )
    }
    _ -> ProcessInfo(pid, 0, 0, "", "")
  }
}

/// Apply the selected processor.
///
fn do_processing(processes: List(ProcessInfo), processor: Processor) {
  case processor {
    NoProcessor -> processes
    Sort(method) ->
      case method {
        ByMemory -> sort_by_memory(processes)
        CustomSort(custom) -> list.sort(processes, custom)
      }
  }
}

/// Sort a list of ProcessInfo by the memory field.
///
fn sort_by_memory(procs: List(ProcessInfo)) {
  procs
  |> list.sort(fn(a, b) { int.compare(b.memory, a.memory) })
}

// Formatting ----------------------------------------------

fn cloc_to_string(cloc: #(Atom, Atom, Int, List(Dynamic))) {
  icall_to_string(#(cloc.0, cloc.1, cloc.2))
}

fn icall_to_string(icall: #(Atom, Atom, Int)) {
  atom.to_string(icall.0) <> ":" <> atom.to_string(icall.1) <> "/" <> int.to_string(
    icall.2,
  )
}

external fn processes() -> List(Pid) =
  "erlang" "processes"

external fn process_info(Pid, List(Atom)) -> List(ProcessParam) =
  "erlang" "process_info"
