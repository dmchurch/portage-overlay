# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=6

inherit eutils git-r3

DESCRIPTION="Keybase Go client, filesystem, and GUI"
HOMEPAGE="https://keybase.io"
EGIT_REPO_URI="https://github.com/keybase/client.git"
EGIT_CHECKOUT_DIR="client"

LICENSE="BSD"
SLOT="0"
KEYWORDS=""
IUSE=""

DEPEND="
	>=dev-lang/go-1.6:0
	sys-apps/yarn
	net-libs/nodejs[npm]"
RDEPEND="${DEPEND}
	!app-crypt/kbfs
	!app-crypt/keybase-bin
	app-crypt/gnupg
	sys-fs/fuse
	gnome-base/gconf
	x11-libs/libXScrnSaver"

S="${WORKDIR}"

QA_PREBUILT="
	/opt/keybase/Keybase
	/opt/keybase/lib*.so"

src_unpack() {
	git-r3_src_unpack
	EGIT_REPO_URI="${EGIT_REPO_URI//client/kbfs}"
	EGIT_CHECKOUT_DIR="kbfs"
	git-r3_src_unpack
}

src_prepare() {
	eapply_user
	local inhibit_arch
	use amd64 && inhibit_arch=i386
	use x86 && inhibit_arch=amd64
	if [ -n "$inhibit_arch" ]; then
		sed -i '/debian_arch='$inhibit_arch'/,/^$/ s/^build_one/#\0/' client/packaging/linux/build_binaries.sh
	fi
}

src_compile() {
	client/packaging/linux/build_binaries.sh prerelease build_dir
}

src_install() {
	use amd64 && cd build_dir/binaries/amd64
	use x86 && cd build_dir/binaries/i386

	exeinto /opt/keybase
	doexe opt/keybase/Keybase
	doexe opt/keybase/libffmpeg.so
	doexe opt/keybase/libnode.so
	doexe opt/keybase/post_install.sh
	rm -f opt/keybase/{Keybase,lib*.so,post_install.sh}

	insinto /opt
	doins -r opt/keybase

	exeinto /usr/bin
	doexe usr/bin/kbfsfuse
	doexe usr/bin/kbnm
	doexe usr/bin/keybase
	doexe usr/bin/run_keybase

	for d in etc/chromium etc/opt/chrome; do
		insinto /$d/native-messaging-hosts
		doins $d/native-messaging-hosts/io.keybase.kbnm.json
	done

	domenu usr/share/applications/keybase.desktop

	cd usr/share/icons/hicolor
	local size
	for size in *; do
		doicon -s $size $size/apps/keybase.png
	done
}

pkg_postinst() {
	/opt/keybase/post_install.sh
}
