# Distributed under the terms of the GNU General Public License v2

EAPI=7

PATCH_VER=1
PATCH_DEV=dilfridge

inherit eutils libtool toolchain-funcs

MY_PN="binutils"
MY_P="${MY_PN}-${PV}"
PATCH_BINUTILS_VER=${PATCH_BINUTILS_VER:-${PV}}
PATCH_DEV=${PATCH_DEV:-slyfox}

DESCRIPTION="Core binutils libraries (libbfd, libopcodes, libiberty) for external packages"
HOMEPAGE="https://sourceware.org/binutils/"
SRC_URI="mirror://gnu/binutils/${MY_P}.tar.xz
	https://dev.gentoo.org/~${PATCH_DEV}/distfiles/${MY_PN}-${PATCH_BINUTILS_VER}-patches-${PATCH_VER}.tar.xz"

LICENSE="|| ( GPL-3 LGPL-3 )"
SLOT="0/${PV}"
IUSE="64-bit-bfd cet multitarget nls static-libs"
KEYWORDS="*"

BDEPEND="nls? ( sys-devel/gettext )"
DEPEND="sys-libs/zlib"
# Need a newer binutils-config that'll reset include/lib symlinks for us.
RDEPEND="${DEPEND}
	>=sys-devel/binutils-config-5
"
PDEPEND="=sys-devel/binutils-2.36.1-r2"

PATCHES=(
	"${FILESDIR}"/${PN}-2.35.1-cet.patch
	"${REPODIR}"/sys-devel/binutils/files/binutils-2.36.1-cve-2021-45078.patch
)

S="${WORKDIR}/${MY_P}"

src_prepare() {
	if [[ ! -z ${PATCH_VER} ]] ; then
		einfo "Applying binutils-${PATCH_BINUTILS_VER} patchset ${PATCH_VER}"
		eapply "${WORKDIR}/patch"/*.patch
	fi

	# Fix cross-compile relinking issue, bug #626402
	elibtoolize

	default
}

pkgversion() {
	printf "Gentoo ${PVR}"
	[[ -n ${PATCHVER} ]] && printf " p${PATCHVER}"
}

src_configure() {
	local myconf=(
		--enable-obsolete
		--enable-shared
		--enable-threads
		# Newer versions (>=2.24) make this an explicit option. #497268
		--enable-install-libiberty
		--disable-werror
		--with-bugurl="https://bugs.gentoo.org/"
		--with-pkgversion="$(pkgversion)"
		$(use_enable static-libs static)
		# The binutils eclass enables this flag for all bi-arch builds,
		# but other tools often don't care about that support.  Put it
		# beyond a flag if people really want it, but otherwise leave
		# it disabled as it can slow things down on 32bit arches. #438522
		$(use_enable 64-bit-bfd)
		# This only disables building in the zlib subdir.
		# For binutils itself, it'll use the system version. #591516
		--without-zlib
		--with-system-zlib
		# We only care about the libs, so disable programs. #528088
		--disable-{binutils,etc,ld,gas,gold,gprof}
		# Disable modules that are in a combined binutils/gdb tree. #490566
		--disable-{gdb,libdecnumber,readline,sim}
		# Strip out broken static link flags.
		# https://gcc.gnu.org/PR56750
		--without-stage1-ldflags
		# We pull in all USE-flags that change ABI in an incompatible
		# way. #666100
		# USE=multitarget change size of global arrays
		# USE=64-bit-bfd changes data structures of exported API
		--with-extra-soversion-suffix=gentoo-${CATEGORY}-${PN}-$(usex multitarget mt st)-$(usex 64-bit-bfd 64 def)

		# avoid automagic dependency on (currently prefix) systems
		# systems with debuginfod library, bug #754753
		--without-debuginfod

		# Allow user to opt into CET for host libraries.
		# Ideally we would like automagic-or-disabled here.
		# But the check does not quite work on i686: bug #760926.
		$(use_enable cet)
	)

	# mips can't do hash-style=gnu ...
	if [[ $(tc-arch) != mips ]] ; then
		myconf+=( --enable-default-hash-style=gnu )
	fi

	use multitarget && myconf+=( --enable-targets=all --enable-64-bit-bfd )

	use nls \
		&& myconf+=( --without-included-gettext ) \
		|| myconf+=( --disable-nls )

	ECONF_SOURCE=${S} \
	econf "${myconf[@]}"

	# Prevent makeinfo from running as we don't build docs here.
	# bug #622652
	sed -i \
		-e '/^MAKEINFO/s:=.*:= true:' \
		Makefile || die
}

src_install() {
	default
	# Provide libiberty.h directly.
	dosym libiberty/libiberty.h /usr/include/libiberty.h
}

src_install_all() {
	use static-libs || find "${ED}"/usr -name '*.la' -delete
}
