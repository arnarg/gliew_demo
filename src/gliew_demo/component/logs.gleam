import gleam/string
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor
import gleam/erlang/process.{Subject}
import birl/time
import nakai/html
import nakai/html/attrs
import gliew
import gliew_demo/component/util.{send_to_all}

pub fn logs(logger: Subject(Message)) {
  use event <- gliew.live_mount(init_logs, with: logger)

  let ev = case event {
    Some(line) -> html.div_text([], line)
    None -> html.Comment("events come below")
  }

  html.div([attrs.class("log-lines"), gliew.append()], [ev])
}

fn init_logs(logger: Subject(Message)) {
  let subject = process.new_subject()

  process.send(logger, Subscribe(subject))

  subject
}

// Logs actor --------------------------------------------

pub opaque type Message {
  NewEvent(event: String)
  Subscribe(subject: Subject(String))
}

type State {
  State(subscribers: List(Subject(String)))
}

pub fn start_logger() {
  actor.start(State([]), loop)
}

fn loop(msg: Message, state: State) {
  case msg {
    NewEvent(event) ->
      process_event(event, state.subscribers)
      |> State
      |> actor.Continue
    Subscribe(subject) ->
      actor.Continue(State(
        state.subscribers
        |> list.prepend(subject),
      ))
  }
}

fn process_event(event: String, subscribers: List(Subject(String))) {
  time.to_iso8601(time.utc_now()) <> ": " <> event
  |> send_to_all(subscribers)
}

// Helpers ------------------------------------------------

pub fn log_event(logger: Subject(Message), event: String) {
  process.send(logger, NewEvent(event))
}

pub fn init_event(component: String, logger: Subject(Message)) {
  log_event(
    logger,
    "init in component '" <> component <> "' ran in process " <> string.inspect(process.self()),
  )
}
