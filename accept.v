import net as nett

struct Accept {
mut:
	new_conn chan &nett.TcpConn
	l        nett.TcpListener
	level    u8
}

fn (mut a Accept) start() {
	for {
		a.l.wait_for_accept() or { continue }
		mut new := a.l.accept() or { continue }
		new.write([u8(a.level + 1)]) or { continue }
		select {
			a.new_conn <- new {}
		}
	}
}
