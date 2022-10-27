import net { TcpConn }
import time

type Com = Msg | Resp | Scan

struct Msg {
	name string
	msg  string
}

struct Scan {
	time i64
}

struct Resp {
	info Info
}

struct Info {
	level u8
	name  string
	sub   []Info
}

struct ScanReq {
mut:
	target &TcpConn
	all    u8
	time   i64
	infos  []Info
}

struct Net {
mut:
	level    u8
	mconn    &TcpConn
	conns    []&TcpConn
	new_conn chan &TcpConn
	inp      chan Com
	out      chan Com
	sreq     &ScanReq = unsafe { 0 }
	name     string
}

fn (mut n Net) start() {
	for {
		select {
			c := <-n.out {
				match c {
					Msg {
						msg := c.msg.bytes()
						if msg.len > 255 {
							continue
						}
						name := c.name.bytes()
						if name.len > 255 {
							continue
						}
						mut buf := [u8(0x00)]
						buf << u8(name.len)
						buf << name
						buf << u8(msg.len)
						buf << msg
						n.write2all(buf)
					}
					Scan {
						if usize(n.sreq) == 0 {
							continue
						}
						buf := [u8(0x01), u8(c.time >> 8 * 3), u8(c.time >> 8 * 2), u8(c.time >> 8),
							u8(c.time)]
						n.write2all(buf)
						n.sreq = &ScanReq{
							target: &TcpConn(0)
							all: u8(n.conns.len + 1)
							time: c.time
						}
					}
					else {}
				}
			}
		}
		if usize(n.sreq) != 0 {
			if n.sreq.time < time.now().unix_time() {
				if usize(n.sreq.target) == 0 {
					info := Info{
						level: n.level
						name: n.name
						sub: n.sreq.infos
					}
					select {
						n.inp <- Resp{info} {}
					}
					n.sreq = &ScanReq(0)
				} else {
					info := Info{
						level: n.level
						name: n.name
						sub: n.sreq.infos
					}
					n.sreq.target.write(info.tobytes()) or { continue }
					n.sreq = &ScanReq(0)
				}
			}
		}
		n.read(n.mconn)
		for con in n.conns {
			n.read(con)
		}

	}
}

fn (mut n Net) read(con &TcpConn) {
	mut buf := []u8{len: 1}
	con.read(mut buf) or { return }
	match buf[0] {
		0x00 {
			mut ns := []u8{len: 1}
			con.read(mut ns) or { return }
			mut name := []u8{len: int(ns[0])}
			con.read(mut name) or { return }
			mut ts := []u8{len: 1}
			con.read(mut buf) or { return }
			mut text := []u8{len: int(ts[0])}
			con.read(mut text) or { return }
			mut ret := []u8{}
			ret << 0x00
			ret << ns
			ret << name
			ret << ts
			ret << text
			n.write2other(ret, con)
			select {
				n.inp <- Msg{name.bytestr(), text.bytestr()} {}
			}
		}
		0x01 {
			if usize(n.sreq) != 0 {
				return
			}
			mut timeb := []u8{len: 4}
			con.read(mut timeb) or { return }
			mut time := i64(0)
			time |= timeb[0] << 8 * 3
			time |= timeb[1] << 8 * 2
			time |= timeb[2] << 8
			time |= timeb[3]
			time -= 3
			n.sreq = &ScanReq{
				target: con
				all: u8(n.conns.len)
				time: time
			}
			timen := [u8(0x01), u8(c.time >> 8 * 3), u8(c.time >> 8 * 2), u8(c.time >> 8), u8(c.time)]
			n.write2other(timen, con)
		}
		0x02 {
			if usize(n.sreq) == 0 {
				return
			}
			
		}
		else {}
	}
}

fn (i Info) tobytes() []u8 {
	// todo
	mut buf := []u8{}
	sb := i.name.bytes()
	buf << sb
	return buf
}

fn (mut n Net) write2all(bytes []u8) {
	n.mconn.write(bytes) or {}
	for mut c in n.conns {
		c.write(bytes) or {}
	}
}

fn (mut n Net) write2other(bytes []u8, con &TcpConn) {
	if usize(n.mconn) != usize(con) {
		n.mconn.write(bytes) or {}
	}
	for mut c in n.conns {
		if usize(c) == usize(con) {
			continue
		}
		c.write(bytes) or {}
	}
}
