#!/usr/bin/env bash

# Edit By Alexander Eric@Eric Lapin

die() {
	{ test -n "$@" && echo "$@"; exit 1; } >&2
}

mkdir /opt/build
cp -fa /opt/{src,build}/jansson
cp -fa /opt/{src,build}/cjose
cp -fa /opt/{src,build}/openssl

# Build OpenSSL
(
	cd /opt/build/openssl && \
	./config --prefix=/opt/trafficserver/openssl --openssldir=/opt/trafficserver/openssl zlib && \
	make -j`nproc` && \
	make install_sw
) || die "Failed to build OpenSSL"
	

(cd /opt/build/jansson && patch -p1 < /opt/src/jansson.pic.patch && autoreconf -i && ./configure --enable-shared=no && make -j`nproc` && make install) || die "Failed to install jansson from source."
(cd /opt/build/cjose && patch -p1 < /opt/src/cjose.pic.patch && autoreconf -i && ./configure --enable-shared=no --with-openssl=/opt/trafficserver/openssl && make -j`nproc` && make install) || die "Failed to install cjose from source."
cp -far /opt/src/astats_over_http /rpmbuilddir/SOURCES/src/plugins/astats_over_http
cat > /rpmbuilddir/SOURCES/src/plugins/astats_over_http/Makefile.inc <<MAKEFILE
pkglib_LTLIBRARIES += astats_over_http/astats_over_http.la
astats_over_http_astats_over_http_la_SOURCES = astats_over_http/astats_over_http.c
MAKEFILE
(ed /rpmbuilddir/SOURCES/src/plugins/Makefile.am <<ED
/stats_over_http/
t
s/stats/astats/g
w
ED
) || die "Failed to patch plugins makefile to include astats."
(sed -i 's/ExecStart=@exp_bindir@\/traffic_manager \$TM_DAEMON_ARGS/ExecStart=@exp_bindir@\/traffic_manager --bind_stdout @exp_logdir@\/traffic.out --bind_stderr @exp_logdir@\/traffic.out \$TM_DAEMON_ARGS/g' /rpmbuilddir/SOURCES/src/rc/trafficserver.service.in)
(sed -i 's/After=syslog.target network.target/Wants=systemd-udev-settle.service \nAfter=syslog.target network.target systemd-udev-settle.service/g' /rpmbuilddir/SOURCES/src/rc/trafficserver.service.in)
rpmbuild -bb --define "_topdir /rpmbuilddir" /rpmbuilddir/SPECS/trafficserver.spec || die "Failed to build rpm."
