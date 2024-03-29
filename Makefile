WASI_SDK_PATH = $(CURDIR)/build/wasi-sdk

vendor/wasi-sdk-download-x86_64-linux.tar.gz:
	curl -L -o $@ https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-21/wasi-sdk-21.0-linux.tar.gz

build/wasi-sdk.stamp: vendor/wasi-sdk-download-x86_64-linux.tar.gz
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
	$(MAKE) -C build/ruby install DESTDIR=$(CURDIR)/build/ruby-root
	touch $@

build/wasi_snapshot_preview1.command.wasm:
	curl -L -o $@ https://github.com/bytecodealliance/wasmtime/releases/download/v17.0.1/wasi_snapshot_preview1.command.wasm

RUBY_ROOT = build/ruby-root

build/ruby.wasm: build/wasi-sdk.stamp wasm-tools/target/debug/wasm-tools build/ruby.make.stamp build/wasi_snapshot_preview1.command.wasm
	./wasm-tools/target/debug/wasm-tools component link $(RUBY_ROOT)/usr/local/bin/ruby \
	  $(WASI_SDK_PATH)/share/wasi-sysroot/lib/wasm32-wasi/libc.so \
	  $(WASI_SDK_PATH)/share/wasi-sysroot/lib/wasm32-wasi/libwasi-emulated-getpid.so \
	  $(WASI_SDK_PATH)/share/wasi-sysroot/lib/wasm32-wasi/libwasi-emulated-mman.so \
	  $(WASI_SDK_PATH)/share/wasi-sysroot/lib/wasm32-wasi/libwasi-emulated-process-clocks.so \
	  $(WASI_SDK_PATH)/share/wasi-sysroot/lib/wasm32-wasi/libwasi-emulated-signal.so \
	  $(WASI_SDK_PATH)/share/wasi-sysroot/lib/wasm32-wasi/libdl.so \
	  --adapt ./build/wasi_snapshot_preview1.command.wasm \
	  --dl-openable /usr/local/lib/ruby/3.4.0+0/wasm32-wasi/enc/encdb.so=$(RUBY_ROOT)/usr/local/lib/ruby/3.4.0+0/wasm32-wasi/enc/encdb.so \
	  --dl-openable /usr/local/lib/ruby/3.4.0+0/wasm32-wasi/stringio.so=$(RUBY_ROOT)/usr/local/lib/ruby/3.4.0+0/wasm32-wasi/stringio.so \
	  --dl-openable /usr/local/lib/ruby/3.4.0+0/wasm32-wasi/monitor.so=$(RUBY_ROOT)/usr/local/lib/ruby/3.4.0+0/wasm32-wasi/monitor.so \
	  --dl-openable /usr/local/lib/ruby/3.4.0+0/wasm32-wasi/pathname.so=$(RUBY_ROOT)/usr/local/lib/ruby/3.4.0+0/wasm32-wasi/pathname.so \
	  --dl-openable /usr/local/lib/ruby/3.4.0+0/wasm32-wasi/strscan.so=$(RUBY_ROOT)/usr/local/lib/ruby/3.4.0+0/wasm32-wasi/strscan.so \
	  -o $@
	  # --use-built-in-libdl \
	  # --dl-openable /usr/local/lib/ruby/site_ruby/3.4.0+0/wasm32-wasi/nokogiri/nokogiri.so=$(RUBY_ROOT)/usr/local/lib/ruby/site_ruby/3.4.0+0/wasm32-wasi/nokogiri/nokogiri.so \
	  # --dl-openable /build/ruby/.ext/wasm32-wasi/stringio.so=./build/ruby/.ext/wasm32-wasi/stringio.so -o $@
	  # --adapt /home/katei/ghq/github.com/bytecodealliance/wasmtime/target/wasm32-unknown-unknown/debug/wasi_snapshot_preview1.wasm \
	  # --adapt ./build/wasi_snapshot_preview1.command.wasm \

.PHONY: check clean

check: build/ruby.wasm
	wasmtime run --wasm component-model --dir ./build/ruby-root/usr/::/usr build/ruby.wasm -e 'require "stringio.so"; puts StringIO.new'

clean:
	rm -rf build
