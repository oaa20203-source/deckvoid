# Support debug and release builds from command line for CI
CONFIG += debug_and_release

# Ensure symbols are always generated
CONFIG += force_debug_info

# Disable asserts on release builds
CONFIG(release, debug|release) {
    DEFINES += NDEBUG
}

# Enable CFG, EHCont, and CET
*-msvc {
    QMAKE_CFLAGS += -guard:cf -guard:ehcont
    QMAKE_CXXFLAGS += -guard:cf -guard:ehcont
    QMAKE_LFLAGS += -guard:cf -guard:ehcont

    contains(QT_ARCH, x86_64) {
        QMAKE_LFLAGS += -cetcompat
    }
}

# macOS: target macOS 27 on Apple Silicon only.
# - The instruction set stays at the M1 baseline so every Apple Silicon Mac that
#   runs macOS 27 can start the app; scheduling is tuned for M5.
# - Release builds use -O3 and ThinLTO. The static libraries (moonlight-common-c,
#   qmdnsengine, h264bitstream, pyrowave) are LTO'd into the app as well.
macx {
    QMAKE_MACOSX_DEPLOYMENT_TARGET = 27.0
    QMAKE_APPLE_DEVICE_ARCHS = arm64

    QMAKE_CFLAGS   += -mcpu=apple-m1 -mtune=apple-m5
    QMAKE_CXXFLAGS += -mcpu=apple-m1 -mtune=apple-m5
    QMAKE_OBJECTIVE_CFLAGS += -mcpu=apple-m1 -mtune=apple-m5

    CONFIG(release, debug|release) {
        QMAKE_CFLAGS_RELEASE   -= -O2
        QMAKE_CXXFLAGS_RELEASE -= -O2
        QMAKE_CFLAGS_RELEASE_WITH_DEBUGINFO   -= -O2
        QMAKE_CXXFLAGS_RELEASE_WITH_DEBUGINFO -= -O2
        QMAKE_CFLAGS   += -O3 -flto=thin
        QMAKE_CXXFLAGS += -O3 -flto=thin
        QMAKE_OBJECTIVE_CFLAGS += -O3 -flto=thin
        QMAKE_LFLAGS   += -flto=thin -Wl,-cache_path_lto,$$OUT_PWD/.lto-cache -Wl,-dead_strip
    }
}

# Enable ASan for Linux or macOS
#CONFIG += sanitizer sanitize_address

# Enable ASan for Windows
#QMAKE_CFLAGS += -fsanitize=address
#QMAKE_CXXFLAGS += -fsanitize=address
#QMAKE_LFLAGS += -incremental:no

# Propagate environment variable flags
QMAKE_CFLAGS   += $$(CFLAGS)
QMAKE_CXXFLAGS += $$(CXXFLAGS)
QMAKE_LFLAGS   += $$(LDFLAGS)
