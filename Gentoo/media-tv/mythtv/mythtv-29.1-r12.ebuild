# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit user flag-o-matic eutils

DESCRIPTION="Free Open Source software digital video recorder (DVR) project"
HOMEPAGE="https://www.mythtv.org/"
LICENSE="GPL-2"

MYTHTV_REV=60e40b352ab95a135ec2ab8f9f1ee93b4f9d245e
MYTHTV_SHORT_REV=60e40b3
REPO=mythtv

MYTHTV_GROUPS="video,audio,tty,uucp"

SRC_URI="https://github.com/MythTV/${REPO}/tarball/${MYTHTV_REV} -> ${REPO}-${PVR}.tar.gz"

#where to configure/make/etc
S="${WORKDIR}/MythTV-${REPO}-${MYTHTV_SHORT_REV}/mythtv"

SLOT="0"
KEYWORDS="~amd64 ~arm ~ia64 ~ppc ~ppc64 ~x86"
IUSE="mp3
alsa
ass
cec
dvb
fftw
hls
ieee1394
jack
lirc
pulseaudio
raop
vaapi
vdpau
xvid
altivec
debug
crystalhd
procopt
sdl2
logserver
xvmc
"

COMMON_DEP="
	virtual/mysql
	virtual/opengl
	x11-libs/libXext
	x11-libs/libXinerama
	x11-libs/libXv
	x11-libs/libXrandr
	x11-libs/libXxf86vm
	>=dev-qt/qtcore-5.2:5
	>=dev-qt/qtwebkit-5.2:5
	>=dev-qt/qtopengl-5.2:5
	>=dev-qt/qtscript-5.2:5
	>=dev-qt/qtwidgets-5.2:5
	alsa? ( >=media-libs/alsa-lib-0.9 )
	ass? ( media-libs/libass )
	dev-libs/libxml2
	cec? (	dev-libs/libcec )
	dvb? (	virtual/linuxtv-dvb-headers )
	fftw? (	sci-libs/fftw )
	hls? (	media-sound/lame
		>=media-libs/x264-0.0.20100605
		media-libs/libvpx )
	ieee1394? (	>=sys-libs/libavc1394-0.5.3
		>=media-libs/libiec61883-1.0.0 )
	jack? ( media-sound/jack-audio-connection-kit )
	lirc? ( app-misc/lirc )
	pulseaudio? ( media-sound/pulseaudio )
	raop? (	net-dns/avahi[mdnsresponder-compat] )
	vaapi? ( x11-libs/libva )
	vdpau? ( x11-libs/libvdpau )
	media-libs/faad2
	media-libs/libvorbis
	xvid? ( media-libs/xvid )
	sdl2? ( media-libs/libsdl2 )
	xvmc? ( x11-libs/libXvMC )
"

DEPEND="${COMMON_DEP}
	dev-lang/yasm
"
RDEPEND="${COMMON_DEP}"

DOCS="AUTHORS FAQ UPGRADING  README"

src_prepare(){
	default
	epatch "${FILESDIR}/ldconfSandbox-29.patch"
	epatch "${FILESDIR}/nostrip-29.patch"
}

src_configure() {
	local myconf="--prefix=/usr --datadir=/usr/share"
	myconf="${myconf} --mandir=/usr/share/man"
	myconf="${myconf} --libdir-name=$(get_libdir)"

	#ffmpeg
	myconf="${myconf} --disable-stripping"
	
	myconf="${myconf} --enable-pic"

	use alsa       || myconf="${myconf} --disable-audio-alsa"
	use altivec    || myconf="${myconf} --disable-altivec"
	use jack       || myconf="${myconf} --disable-audio-jack"
	use pulseaudio || myconf="${myconf} --disable-audio-pulseoutput"

	myconf="${myconf} $(use_enable dvb)"
	if use dvb
	then
		myconf="${myconf} --dvb-path=/usr/include"
	fi
	myconf="${myconf} $(use_enable ieee1394 firewire)"
	myconf="${myconf} $(use_enable lirc)"

	#bindings handled in media-tv/mythtv-bindings
	myconf="${myconf} --without-bindings=perl,python,php"

	if use debug
	then
		myconf="${myconf} --compile-type=debug"
	else
		myconf="${myconf} --compile-type=release"
	fi

	myconf="${myconf} $(use_enable vdpau)"

	myconf="${myconf} $(use_enable vaapi)"
	
	myconf="${myconf} $(use_enable crystalhd)"
	
	myconf="${myconf} $(use_enable xvmc)"

	myconf="${myconf} $(use_enable xvid libxvid)"

	if use hls
	then
		myconf="${myconf} --enable-libmp3lame"
		myconf="${myconf} --enable-libx264"
		myconf="${myconf} --enable-libvpx"
		myconf="${myconf} --enable-nonfree"
	fi

	myconf="${myconf} $(use_enable cec libcec)"

	myconf="${myconf} --enable-symbol-visibility"
	
	if use procopt
	then
		myconf="${myconf} --enable-proc-opt"
	fi
	
	myconf="${myconf} $(use_enable sdl2)"
	
	myconf="${myconf} $(use_enable logserver mythlogserver)"

	has distcc ${FEATURES} || myconf="${myconf} --disable-distcc"
	has ccache ${FEATURES} || myconf="${myconf} --disable-ccache"

# let MythTV come up with our CFLAGS. Upstream will support this
	strip-flags

	chmod +x ./external/FFmpeg/version.sh

	einfo "Running ./configure ${myconf}"
	chmod +x ./configure
	./configure ${myconf} || die "configure failed"
}

src_install() {
	make INSTALL_ROOT="${D}" install || die "install failed"
	dodoc ${DOCS}

	insinto /usr/share/mythtv/database
	doins database/*

	newinitd "${FILESDIR}"/mythbackend-0.25.rc mythbackend
	newconfd "${FILESDIR}"/mythbackend-0.25.conf mythbackend

	dodoc keys.txt
	#dohtml docs/*.html

	keepdir /etc/mythtv
	chown -R mythtv "${D}"/etc/mythtv
	keepdir /var/log/mythtv
	chown -R mythtv "${D}"/var/log/mythtv

	insinto /etc/logrotate.d
	newins "${FILESDIR}"/mythtv.29.logrotate.d mythtv

	#insinto /etc/cron.daily
	#insopts -m0544
	#newins "${FILESDIR}"/runlogcleanup mythtv.logcleanup

	dodir /usr/share/mythtv/bin
	exeinto /usr/share/mythtv/bin
	doexe "${FILESDIR}"/logcleanup.py
    

	insinto /usr/share/mythtv/contrib
	insopts -m0644
	doins -r contrib/*

}

pkg_postinst() {
	enewuser mythtv -1 /bin/bash /home/mythtv ${MYTHTV_GROUPS}
	#usermod -a -G ${MYTHTV_GROUPS} mythtv
}