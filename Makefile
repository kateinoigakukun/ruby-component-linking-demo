WASI_SDK_PATH = $(CURDIR)/build/wasi-sdk

build/wasi-sdk.stamp: vendor/wasi-sdk-next-x86_64-linux.tar.gz
	mkdir -p build/wasi-sdk
	tar -C build/wasi-sdk --strip-components=1 -xf $<
	touch $@

wasm-tools/target/debug/wasm-tools:
	cargo build --manifest-path wasm-tools/Cargo.toml

build/ruby.configure.stamp: build/wasi-sdk.stamp
	mkdir -p build/ruby
	./ruby/autogen.sh
	(cd build/ruby && env WASI_SDK_PATH=$(WASI_SDK_PATH) ../../configure-wasm32-wasi-pic)
	touch $@

build/ruby.make.stamp: build/ruby.configure.stamp
	# HACK: "AR" is well propagated to mkmf so static-lib build is fine, but
	#       "LD" is not, so we need to override it via environment variable.
	env \
	  LD=$(WASI_SDK_PATH)/bin/clang \
	  $(MAKE) -C build/ruby
	touch $@

build/wasi_snapshot_preview1.command.wasm:
	curl -L -o $@ https://github.com/bytecodealliance/wasmtime/releases/download/v15.0.1/wasi_snapshot_preview1.command.wasm

build/ruby.wasm: build/wasi-sdk.stamp wasm-tools/target/debug/wasm-tools build/ruby.make.stamp build/wasi_snapshot_preview1.command.wasm
	./wasm-tools/target/debug/wasm-tools component link build/ruby/ruby \
	  $(WASI_SDK_PATH)/share/wasi-sysroot/lib/wasm32-wasi/libc.so \
	  $(WASI_SDK_PATH)/share/wasi-sysroot/lib/wasm32-wasi/libdl.so \
	  $(WASI_SDK_PATH)/share/wasi-sysroot/lib/wasm32-wasi/libwasi-emulated-getpid.so \
	  $(WASI_SDK_PATH)/share/wasi-sysroot/lib/wasm32-wasi/libwasi-emulated-mman.so \
	  $(WASI_SDK_PATH)/share/wasi-sysroot/lib/wasm32-wasi/libwasi-emulated-process-clocks.so \
	  $(WASI_SDK_PATH)/share/wasi-sysroot/lib/wasm32-wasi/libwasi-emulated-signal.so \
	  --adapt ./build/wasi_snapshot_preview1.command.wasm \
	  --dl-openable /build/ruby/.ext/wasm32-wasi/stringio.so=./build/ruby/.ext/wasm32-wasi/stringio.so -o $@

.PHONY: check clean

check: build/ruby.wasm
	wasmtime run --wasm component-model --dir ./::/ build/ruby.wasm -I build/ruby/.ext/wasm32-wasi -e 'require "stringio.so"; puts StringIO.new'

clean:
	rm -rf build
