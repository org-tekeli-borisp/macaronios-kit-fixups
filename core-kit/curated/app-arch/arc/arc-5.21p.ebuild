# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit toolchain-funcs

DESCRIPTION="Create & extract files from DOS .ARC files"
HOMEPAGE="http://arc.sourceforge.net"
SRC_URI="mirror://sourceforge/${PN}/${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="*"

PATCHES=(
	"${FILESDIR}"/${PN}-5.21m-darwin.patch
	"${FILESDIR}"/${PN}-5.21m-gentoo-fbsd.patch
	"${FILESDIR}"/${PN}-5.21o-interix.patch
	"${FILESDIR}"/${PN}-5.21p-fno-common.patch
)

src_prepare() {
	default

	sed -i Makefile \
		-e 's/CFLAGS = $(OPT) $(SYSTEM)/CFLAGS += $(SYSTEM)/' \
		|| die "sed Makefile"
}

src_compile() {
	emake CC="$(tc-getCC)" OPT="${LDFLAGS}"
}

src_install() {
	dobin arc marc
	doman arc.1
	dodoc Arc521.doc Arcinfo Changelog Readme
}
