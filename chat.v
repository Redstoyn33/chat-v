import term.ui as tui
import time
import os

struct Chat {
mut:
	tui       &tui.Context = unsafe { 0 }
	name      string
	format    string
	text      string
	buf       &LoopArr
	inp       chan Com
	out       chan Com
	level     u8
	wait_scan i64
}

fn (mut c Chat) start() {
	c.tui = tui.init(
		user_data: c
		event_fn: event
		frame_fn: frame
		hide_cursor: false
		frame_rate: 10
	)
	c.tui.run() or {
		os.input('Ошибка терминала')
		exit(3)
	}
}

fn event(e &tui.Event, x voidptr) {
	if e.typ == .key_down {
		mut c := &Chat(x)
		match e.code {
			.escape {
				exit(0)
			}
			.backspace {
				if c.text.len == 0 {
					return
				}
				c.text = c.text[..c.text.len - 1]
			}
			.enter {
				if c.text.len == 0 {
					return
				}
				match c.text {
					'/help' {
						c.buf.add('Гуманитарная помощь:')
					}
					'/level' {
						c.buf.add('Уровень $c.level')
					}
					'/scan' {
						d := Scan{time.now().unix_time()}
						c.out.try_push(d)
						c.buf.add('Начало скана')
					}
					else {
						if c.text.starts_with('/format') {
							if c.text == '/format' {
								c.buf.add('%n - имя, %m - сообщение')
							} else {
								c.format = c.text[8..]
							}
						} else {
							d := Msg{c.name, c.text}
							c.out.try_push(d)
							c.buf.add(c.format.replace_each(['%n', c.name, '%m', c.text]))
						}
					}
				}
				c.text = ''
			}
			else {
				c.text += e.utf8
			}
		}
	}
}

fn frame(x voidptr) {
	mut c := &Chat(x)
	for {
		select {
			s := <-c.inp {
				match s {
					Msg {
						c.buf.add(c.format.replace_each(['%n', s.name, '%m', s.msg]))
					}
					Resp {
						s.info.print(mut c.buf, 0)
					}
					else {}
				}
			}
			else {
				break
			}
		}
	}
	c.tui.clear()
	for i in 0 .. c.tui.window_height {
		if c.buf.len <= i {
			break
		}
		c.tui.draw_text(0, c.tui.window_height - 1 - i, c.buf.get(c.buf.len - 1 - i))
	}
	c.tui.draw_text(0, c.tui.window_height, c.enter)
	c.tui.flush()
}

fn (i Info) print(mut a LoopArr, tab int) {
	a.add('|-'.repeat(tab) + '$i.name [$i.level.str()]')
	for ii in i.sub {
		ii.print(mut a, tab + 1)
	}
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
