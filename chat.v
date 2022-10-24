import term.ui as tui
import os
import net
import time

struct Chat {
mut:
	tui    &tui.Context = unsafe { 0 }
	name   string
	format string
	text   string
	buf    LoopArr
	inp    chan Com
	out    chan Com
}

fn (mut c Chat) start() {
	c.tui = tui.init(
		user_data: c
		event_fn: event
		frame_fn: frame
		hide_cursor: false
		frame_rate: 10
	)
	app.tui.run()?
}

fn event(e &tui.Event, x voidptr) {
	if e.typ == .key_down {
		mut c := &Chat(x)
		match e.code {
			.escape {
				exit(0)
			}
			.backspace {
				if app.enter.len == 0 {
					return
				}
				app.enter = app.enter[..app.enter.len - 1]
			}
			.enter {
				if app.enter.len == 0 {
					return
				}
				app.out.try_push(app.enter)
				app.buf << '< ' + app.enter
				app.enter = ''
			}
			else {
				app.enter += e.utf8
			}
		}
	}
}

fn frame(x voidptr) {
	mut c := &Chat(x)
}

struct LoopArr {
	len int = 10
mut:
	arr []string = []string{cap: 10}
	pos int      = 0
}

fn (a LoopArr) get(i int) string {
	return a.arr[(a.pos + i) % a.len]
}

fn (mut a LoopArr) add(s string) {
	a.pos = if a.pos == 0 { a.len - 1 } else { a.pos - 1 }
	a.arr[a.pos] = s
}

type Com = Msg | Resp | Scan

struct Msg {
	name string
	msg  string
}

struct Scan {
	time int
}

struct Resp {
	info Info
}

struct Info {
	level u8
	name  string
	sub   []Info
}

fn main() {
	os
}
