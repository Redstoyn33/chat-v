import net { TcpConn }

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
	target &TcpConn
	all    u8
	time   i64
	infos  []Info
	wait   bool
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
						buf := [u8(name.len)]
						buf << name
						buf << u8(msg.len)
						buf << msg
					}
				}
			}
		}
	}
}

fn (mut n Net) write2all(bytes []u8) {
	n.mconn.write(bytes) or {}
	for c in n.conns {
		c.write(bytes) or {}
	}
}

fn (mut n Net) write2other(bytes []u8, con &TcpConn) {
	if unsafe { n.mconn != con } {
		n.mconn.write(bytes) or {}
	}
	for c in n.conns {
		if unsafe { c == con } {
			continue
		}
		c.write(bytes) or {}
	}
}
