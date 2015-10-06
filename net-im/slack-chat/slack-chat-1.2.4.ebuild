# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5

inherit eutils unpacker

SRC_URI_BASE="https://slack-ssb-updates.global.ssl.fastly.net/linux_releases/slack-desktop"

DESCRIPTION="Slack Chat (Beta) for Linux"
HOMEPAGE="https://slack.com"
SRC_URI="x86? ( ${SRC_URI_BASE}-${PV}-i386.deb )
	amd64? ( ${SRC_URI_BASE}-${PV}-amd64.deb )"
RESTRICT="mirror strip"

LICENSE="slack"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

DEPEND=""
RDEPEND="
	gnome-base/gconf:2
	x11-libs/gtk+:2
	dev-libs/libgcrypt
	x11-libs/libnotify
	x11-libs/libXext
	dev-libs/nss
	gnome-base/gvfs
	x11-misc/xdg-utils
	app-text/hunspell
	dev-libs/expat
"

S=${WORKDIR}

QA_PREBUILT="*"

src_prepare() {
	sed -i 's!/usr/share/slack!/opt/slack!' usr/share/applications/slack.desktop || \
		die "Patching desktop file failed"
}

src_install() {
	exeinto /opt/slack
	doexe usr/share/slack/slack
	doexe usr/share/slack/libnode.so
	rm -f usr/share/slack/{slack,lib*.so*}

	dodir /opt/bin
	dosym ../slack/slack /opt/bin/slack || die

	insinto /opt
	doins -r usr/share/slack

	domenu usr/share/applications/slack.desktop
	doicon usr/share/pixmaps/slack.png
}
