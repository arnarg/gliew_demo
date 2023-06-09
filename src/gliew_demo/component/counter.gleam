import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/function
import gleam/otp/actor
import gleam/erlang/process.{Subject}
import gleam/http.{Post}
import nakai/html
import nakai/html/attrs
import gliew
import gliew_demo/component/logs.{Message as LoggerMessage}

pub type CounterContext {
  CounterContext(counter: Subject(Message), logger: Subject(LoggerMessage))
}

pub fn counter(context: CounterContext) {
  html.div(
    [],
    [
      counter_mount(context),
      html.button_text([], "Reset")
      |> gliew.on_click(do: Post, to: "/counter/reset"),
    ],
  )
}

fn counter_mount(context: CounterContext) {
  use assign <- gliew.live_mount(init_counter, with: context)

  let current = case assign {
    Some(count) -> count
    None -> get_current(context.counter)
  }

  html.div_text(
    [attrs.class("counter")],
    current
    |> int.to_string,
  )
}

fn init_counter(context: CounterContext) {
  // Log event
  logs.init_event("counter", context.logger)

  // Create a new subject to subscribe to
  let subject = process.new_subject()

  // Subscribe to counter
  process.send(context.counter, Subscribe(subject))

  subject
}

pub fn reset_counter(context: CounterContext) {
  logs.log_event(context.logger, "resetting counter!")

  reset(context.counter)

  gliew.response(204)
}

// Counter actor -----------------------------------------------

type State {
  State(self: Subject(Message), counter: Int, subscribers: List(Subject(Int)))
}

pub opaque type Message {
  Increment
  Reset
  Subscribe(subject: Subject(Int))
  GetCurrent(from: Subject(Int))
}

pub fn start_counter() {
  actor.start_spec(actor.Spec(
    init: fn() {
      // Create a subject for ourselves
      let self = process.new_subject()

      // Select our own messages
      let selector =
        process.new_selector()
        |> process.selecting(self, function.identity)

      // Send the initial increment message
      let _ = process.send_after(self, 1000, Increment)

      // Actor ready
      actor.Ready(State(self, 0, []), selector)
    },
    init_timeout: 1000,
    loop: counter_loop,
  ))
}

fn counter_loop(msg: Message, state: State) {
  case msg {
    // Increment the counter.
    // Should happen every second.
    Increment -> {
      // Increment the counter by 1.
      let new_counter = state.counter + 1

      // Send new counter to all subscribers while also
      // filtering for dead processes.
      let new_subscribers = send_to_all(new_counter, state.subscribers)

      // Send an increment to ourselves in a second.
      let _ = process.send_after(state.self, 1000, Increment)

      // Continue actor.
      actor.Continue(
        State(..state, counter: new_counter, subscribers: new_subscribers),
      )
    }
    // Reset the counter.
    Reset -> {
      // Send 0 to all subscribers while also filtering for
      // dead processes.
      let new_subscribers = send_to_all(0, state.subscribers)

      // Continue actor.
      actor.Continue(State(..state, counter: 0, subscribers: new_subscribers))
    }
    // Subscribe to the counter.
    Subscribe(subject) -> {
      // Send current value
      process.send(subject, state.counter)

      // Continue actor with new subject subscribed
      actor.Continue(
        State(
          ..state,
          subscribers: state.subscribers
          |> list.prepend(subject),
        ),
      )
    }
    // Return current state.
    GetCurrent(from) -> {
      process.send(from, state.counter)

      actor.Continue(state)
    }
  }
}

fn send_to_all(counter: Int, subscribers: List(Subject(Int))) {
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
          process.send(next, counter)

          send_to_all(counter, rest)
          |> list.prepend(next)
        }
        False -> send_to_all(counter, rest)
      }
  }
}

fn get_current(count_actor: Subject(Message)) {
  process.call(count_actor, GetCurrent, 1000)
}

pub fn reset(count_actor: Subject(Message)) {
  process.send(count_actor, Reset)
}
