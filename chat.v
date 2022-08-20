import term.ui as tui
import os { input }
import net
import time

struct App {
mut:
	tui   &tui.Context = unsafe { 0 }
	enter string
	buf   []string    = []string{cap: 10}
	inp   chan string = chan string{cap: 3}
	out   chan string = chan string{cap: 1}
}

fn event(e &tui.Event, x voidptr) {
	if e.typ == .key_down {
		mut app := &App(x)
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
	mut app := &App(x)
	select {
		s := <-app.inp {
			app.buf << '> ' + s
		}
		else {}
	}
	app.tui.clear()
	for i in 0 .. app.tui.window_height {
		if app.buf.len <= i {
			break
		}
		app.tui.draw_text(0, app.tui.window_height - 1 - i, app.buf[app.buf.len - 1 - i])
	}
	app.tui.draw_text(0, app.tui.window_height, app.enter )
	app.tui.flush()
}

fn main() {
	h := input('enter для подключения, любой текст для хостинга - ')
	mut con := &net.TcpConn(0)
	if h.len == 0 {
		adr := input('адрес подключения - ')
		con = net.dial_tcp(adr) or {
			println('неудалось соединится')
			input('')
			exit(1)
		}
	} else {
		adr := input('порт хоста - ')
		if !adr.contains_only('0123456789') {
			println('неверный порт')
			input('')
			exit(1)
		}
		mut listener := net.listen_tcp(.ip, ':' + adr)?
		listener.wait_for_accept()?
		con = listener.accept() or {
			println('неудалось соединится')
			input('')
			exit(1)
		}
	}
	con.set_read_timeout(time.second / 5)
	mut app := &App{}
	go con_hand(app.inp, app.out, mut con)
	app.tui = tui.init(
		user_data: app
		event_fn: event
		frame_fn: frame
		hide_cursor: false
		frame_rate: 10
	)
	app.tui.run()?
}

fn con_hand(inp chan string, out chan string, mut con net.TcpConn) {
	for {
		select {
			s := <-out {
				b := s.bytes()
				if b.len > 256 { continue }
				con.write([u8(b.len)]) or { exit(1) }
				con.write(b) or { exit(1) }
			}
			else {
				mut num := []u8{len: 1}
				con.read(mut num) or { continue }
				mut buf := []u8{len: int(num[0])}
				con.read(mut buf) or { continue }
				s := buf.bytestr()
				inp.try_push(s)
			}
		}
	}
}
