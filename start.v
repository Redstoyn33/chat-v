import os
import net as nett { TcpConn }
import time

fn main() {
	name := os.input('Введите имя - ')
	addr := os.input('Введите адрес (оставте пустым для хоста) - ')
	port := os.input('Порт - ')
	mconn := if addr == '' {
		&TcpConn(0)
	} else {
		mut n := nett.dial_tcp(addr) or {
			os.input('Не удалось подключится')
			exit(1)
		}
		n.set_read_timeout(time.second*2)
		n
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
	mut chat := &Chat{
		name: name
		format: '%n > %m'
		text: ''
		buf: &LoopArr{
			len: 10
			arr: []string{len: 10}
		}
		inp: inp
		out: out
		level: level
	}
	mut accept := &Accept{
		new_conn: new_conn
		l: nett.listen_tcp(.ip, ':' + port) or {
			os.input('Ошибка хостинга')
			exit(4)
		}
		level: level
	}
	println('Запуск')
	go net.start()
	go accept.start()
	chat.start()
}
