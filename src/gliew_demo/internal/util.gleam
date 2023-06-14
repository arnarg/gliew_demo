import gleam/list
import gleam/erlang/process.{Subject}

pub fn send_to_all(msg: a, subscribers: List(Subject(a))) {
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
          process.send(next, msg)

          send_to_all(msg, rest)
          |> list.prepend(next)
        }
        False -> send_to_all(msg, rest)
      }
  }
}
