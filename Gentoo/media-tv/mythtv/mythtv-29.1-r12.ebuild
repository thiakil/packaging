# Distributed under the terms of the GNU General Public License v2

EAPI=6



DESCRIPTION="Free Open Source software digital video recorder (DVR) project"
HOMEPAGE="https://www.mythtv.org/"
LICENSE="GPL-2"

MYTHTV_REV=60e40b352ab95a135ec2ab8f9f1ee93b4f9d245e
MYTHTV_SHORT_REV=60e40b3
REPO=mythtv

SRC_URI="https://github.com/MythTV/${REPO}/tarball/${MYTHTV_REV} -> ${REPO}-${PVR}.tar.gz"

#where to configure/make/etc
S="${WORKDIR}/MythTV-${REPO}-${MYTHTV_SHORT_REV}/mythtv"

SLOT="0"
KEYWORDS="~amd64 ~arm ~ia64 ~ppc ~ppc64 ~x86"
IUSE="mp3
x11
alsa
ass
cec
dvb
fftw
hls
ieee1394
jack
lirc
perl
pulseaudio
python
raop
vaapi
vdpau
xvid"

#xvmc?

COMMON_DEP="
	mp3? ( media-sound/lame )
	virtual/mysql
	virtual/opengl
	x11? ( x11-libs/libXext
		x11-libs/libXinerama
		x11-libs/libXv
		x11-libs/libXrandr
		x11-libs/libXxf86vm )
	>=dev-qt/qtcore-5.2:5
	>=dev-qt/qtwebkitl-5.2:5
	>=dev-qt/qtopengl-5.2:5
	>=dev-qt/qtscript-5.2:5
	alsa? ( >=media-libs/alsa-lib-0.9 )
	ass? ( media-libs/libass )
	dev-libs/libxml2
	cec? (	dev-libs/libcec )
	dvb? (	virtual/linuxtv-dvb-headers )
	fftw? (	sci-libs/fftw )
	hls? (	>=media-libs/x264-0.0.20100605
		media-libs/libvpx
		media-libs/flac )
	ieee1394? (	>=sys-libs/libavc1394-0.5.3
		>=media-libs/libiec61883-1.0.0 )
	jack? ( media-sound/jack-audio-connection-kit )
	lirc? ( app-misc/lirc )
	perl? (	dev-perl/DBD-mysql
		dev-perl/Net-UPnP
		dev-perl/LWP-Protocol-https
		dev-perl/IO-Socket-INET6
		>=dev-perl/libwww-perl-5
		dev-perl/Class-DBI
		dev-perl/DBD-mysql
		dev-perl/Date-Manip
		dev-perl/DateTime-Format-ISO8601 
		dev-perl/Image-Size 
		dev-perl/JSON
		dev-perl/SOAP-Lite
		dev-perl/XML-Simple
		dev-perl/XML-XPath )
	pulseaudio? ( media-sound/pulseaudio )
	python? (	dev-python/mysql-python
		dev-python/lxml
		dev-python/oauth
		dev-python/pycurl
		dev-python/urlgrabber )
	raop? (	net-dns/avahi[mdnsresponder-compat] )
	vaapi? ( x11-libs/libva )
	vdpau? ( x11-libs/libvdpau )
	media-libs/faad2
	media-libs/libvorbis
	xvid? ( media-libs/xvid )
"

DEPEND="${COMMON_DEP}
	dev-lang/yasm
"
RDEPEND="${COMMON_DEP}"

DOCS="AUTHORS FAQ UPGRADING  README"

pkg_setup() {
	#????
	#python_set_active_version 2
	python_pkg_setup

	enewuser mythtv -1 /bin/bash /home/mythtv ${MYTHTV_GROUPS}
	usermod -a -G ${MYTHTV_GROUPS} mythtv
}

src_configure() {
	local myconf="--prefix=/usr"
	myconf="${myconf} --mandir=/usr/share/man"
	myconf="${myconf} --libdir-name=$(get_libdir)"

	myconf="${myconf} --enable-pic"

	use alsa       || myconf="${myconf} --disable-audio-alsa"
	use altivec    || myconf="${myconf} --disable-altivec"
	use jack       || myconf="${myconf} --disable-audio-jack"
	use pulseaudio || myconf="${myconf} --disable-audio-pulseoutput"

	myconf="${myconf} $(use_enable dvb)"
	myconf="${myconf} $(use_enable ieee1394 firewire)"
	myconf="${myconf} $(use_enable lirc)"
	myconf="${myconf} --dvb-path=/usr/include"
	
	use x11 || myconf="${myconf} --enable-x11"

	#TODO: php
	if use perl && use python
	then
		myconf="${myconf} --with-bindings=perl,python"
	elif use perl
	then
		myconf="${myconf} --without-bindings=python"
		myconf="${myconf} --with-bindings=perl"
	elif use python
	then
		myconf="${myconf} --without-bindings=perl"
		myconf="${myconf} --with-bindings=python"
	else
		myconf="${myconf} --without-bindings=perl,python"
	fi

	if use python
	then
		myconf="${myconf} --python=$(PYTHON)"
	fi

	if use debug
	then
		myconf="${myconf} --compile-type=debug"
	else
		myconf="${myconf} --compile-type=release"
		#myconf="${myconf} --enable-proc-opt"
	fi

	if use vdpau
	then
		myconf="${myconf} --enable-vdpau"
	fi

	if use vaapi
	then
		myconf="${myconf} --enable-vaapi"
	fi
	if use crystalhd
	then
		myconf="${myconf} --enable-crystalhd"
	fi

	myconf="${myconf} $(use_enable xvid libxvid)"

	if use hls
	then
		myconf="${myconf} --enable-libmp3lame"
		myconf="${myconf} --enable-libx264"
		myconf="${myconf} --enable-libvpx"
		myconf="${myconf} --enable-libflac"
		myconf="${myconf} --enable-nonfree"
	fi

	use cec || myconf="${myconf} --disable-libcec"

	myconf="${myconf} --enable-symbol-visibility"

	has distcc ${FEATURES} || myconf="${myconf} --disable-distcc"
	has ccache ${FEATURES} || myconf="${myconf} --disable-ccache"

# let MythTV come up with our CFLAGS. Upstream will support this
	strip-flags
	CFLAGS=""
	CXXFLAGS=""

	chmod +x ./external/FFmpeg/version.sh

	einfo "Running ./configure ${myconf}"
	chmod +x ./configure
	./configure ${myconf} || die "configure died"
}

src_install() {
	make INSTALL_ROOT="${D}" install || die "install failed"
	dodoc ${DOCS}

	insinto /usr/share/mythtv/database
	doins database/*

	exeinto /usr/share/mythtv

	newinitd "${FILESDIR}"/mythbackend-0.25.rc mythbackend
	newconfd "${FILESDIR}"/mythbackend-0.25.conf mythbackend

	dodoc keys.txt docs/*.{txt,pdf}
	dohtml docs/*.html

	keepdir /etc/mythtv
	chown -R mythtv "${D}"/etc/mythtv
	keepdir /var/log/mythtv
	chown -R mythtv "${D}"/var/log/mythtv

	insinto /etc/logrotate.d
	newins "${FILESDIR}"/mythtv.25.logrotate.d mythtv

	insinto /etc/cron.daily
	insopts -m0544
	newins "${FILESDIR}"/runlogcleanup mythtv.logcleanup

	dodir /usr/share/mythtv/bin
	insinto /usr/share/mythtv/bin
	insopts -m0555
	doins "${FILESDIR}"/logcleanup.py
    

	insinto /usr/share/mythtv/contrib
	insopts -m0644
	doins -r contrib/*

}