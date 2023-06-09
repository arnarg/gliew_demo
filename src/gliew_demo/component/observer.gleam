import gleam/int
import gleam/string
import gleam/list
import gleam/option.{None, Some}
import gleam/dynamic.{Dynamic}
import gleam/function
import gleam/otp/actor
import gleam/erlang/process.{Pid, Subject}
import gleam/erlang/atom.{Atom}
import nakai/html
import nakai/html/attrs
import gliew
import gliew_demo/component/util.{send_to_all}

pub type ObserverContext {
  ObserverContext(observer: Subject(Message))
}

pub fn observer(context: ObserverContext) {
  use assign <- gliew.live_mount(init_observer, with: context)

  let rows =
    case assign {
      Some(processes) -> processes
      None -> get_processes()
    }
    |> list.map(fn(p) {
      html.tr(
        [],
        [
          html.td_text([], string.inspect(p.pid)),
          html.td_text([], int.to_string(p.memory)),
          html.td_text([], int.to_string(p.reductions)),
          html.td_text([], p.initial_call),
          html.td_text([], p.current_location),
        ],
      )
    })
    |> html.Fragment

  html.div(
    [gliew.morph()],
    [
      html.table(
        [attrs.Attr("cellspacing", "0"), attrs.Attr("cellpadding", "0")],
        [
          html.tbody(
            [],
            [
              html.tr(
                [attrs.class("theader")],
                [
                  html.th_text([], "PID"),
                  html.th_text([], "Memory"),
                  html.th_text([], "Reductions"),
                  html.th_text([], "Initial Call"),
                  html.th_text([], "Current Function"),
                ],
              ),
              rows,
            ],
          ),
        ],
      ),
    ],
  )
}

fn init_observer(context: ObserverContext) {
  // Create a new subject to subscribe to
  let subject = process.new_subject()

  // Subscribe to monitor
  process.send(context.observer, Subscribe(subject))

  subject
}

// Observer actor --------------------------------------------

pub type ProcessInfo {
  ProcessInfo(
    pid: Pid,
    memory: Int,
    reductions: Int,
    initial_call: String,
    current_location: String,
  )
}

pub opaque type Message {
  Update
  Subscribe(subject: Subject(List(ProcessInfo)))
}

type State {
  State(
    self: Subject(Message),
    interval: Int,
    subscribers: List(Subject(List(ProcessInfo))),
  )
}

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

fn loop(msg: Message, state: State) {
  case msg {
    Update -> {
      // Get all process data and send to subscribers
      let new_subs =
        get_processes()
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

type ProcessParam {
  Memory(Int)
  Reductions(Int)
  InitialCall(#(Atom, Atom, Int))
  CurrentLocation(#(Atom, Atom, Int, List(Dynamic)))
}

pub fn get_processes() -> List(ProcessInfo) {
  processes()
  |> list.map(get_process_info)
}

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
