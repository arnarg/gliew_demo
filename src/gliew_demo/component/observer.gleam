import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/erlang/process
import nakai/html
import nakai/html/attrs
import gliew
import gliew_demo/service/observer.{ByMemory, Observer, Sort}

pub type ObserverContext {
  ObserverContext(observer: Observer)
}

pub fn observer(context: ObserverContext) {
  html.div(
    [],
    [
      html.table(
        [attrs.Attr("cellspacing", "0"), attrs.Attr("cellpadding", "0")],
        [
          html.thead(
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
            ],
          ),
          process_rows(context),
        ],
      ),
    ],
  )
}

fn process_rows(context: ObserverContext) {
  use assign <- gliew.live_mount(init_observer, with: context)

  let you = process.self()

  let rows =
    case assign {
      Some(processes) -> processes
      None -> observer.get_processes(Sort(ByMemory))
    }
    |> list.index_map(fn(i, p) {
      html.tr(
        case p.pid {
          pid if pid == you -> [attrs.class("you")]
          _ -> []
        }
        |> list.prepend(attrs.id("proc-" <> int.to_string(i))),
        [
          html.td_text([], erl_format("~p", [p.pid])),
          html.td_text([], int.to_string(p.memory)),
          html.td_text([], int.to_string(p.reductions)),
          html.td_text([], p.initial_call),
          html.td_text([], p.current_location),
        ],
      )
    })

  html.tbody([gliew.morph()], rows)
}

fn init_observer(context: ObserverContext) {
  // Create a new subject to subscribe to
  let subject = process.new_subject()

  // Subscribe to monitor
  observer.subscribe(context.observer, subject)

  subject
}

external fn erl_format(String, List(a)) -> String =
  "io_lib" "format"
