import os
import net as nett { TcpConn }

fn main() {
	name := os.input('Введите имя - ')
	addr := os.input('Введите адрес (оставте пустым для хоста) - ')
	mconn := if addr == '' {
		&TcpConn(unsafe { 0 })
	} else {
		nett.dial_tcp(addr + ':62352') or {
			os.input('Не удалось подключится')
			exit(1)
		}
	}
	level := if addr == '' {
		0
	} else {
		mut buf := []u8{len: 1}
		mconn.wait_for_read() or {
			os.input('Ошибка соединения')
			exit(2)
		}
		mconn.read(mut buf) or {
			os.input('Ошибка соединения')
			exit(2)
		}
		buf[0]
	}

	new_conn := chan &TcpConn{cap: 1}
	out := chan Com{cap: 10}
	inp := chan Com{cap: 10}

	mut net := &Net{
		level: level
		mconn: mconn
		conns: []&TcpConn{}
		new_conn: new_conn
		inp: inp
		out: out
		name: name
	}
	mut chat := Chat{
		name: name
		format: '%n > %m'
		text: ''
		buf: &LoopArr{
			len: 10
			arr: []string{cap: 10}
		}
		inp: inp
		out: out
		level: level
		wait_scan: 120
	}
	mut accept := &Accept{
		new_conn: new_conn
		l: nett.listen_tcp(.ip, ':62352') or {
			os.input('Ошибка хостинга')
			exit(4)
		}
		level: level
	}
	println("Запуск")
	go net.start()
	go accept.start()
	chat.start()
}
