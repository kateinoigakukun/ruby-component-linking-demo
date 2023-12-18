# ruby-component-linking-demo

This is an experimental setup for building CRuby with WebAssembly [Component Model](https://github.com/WebAssembly/component-model) and
[shared-everything linking](https://github.com/WebAssembly/component-model/blob/main/design/mvp/examples/SharedEverythingDynamicLinking.md) proposals
to enable dynamic linking of CRuby extension libraries.

## Experimental Status

- [x] `require` shared library
- [ ] Import/export WIT interface

## Limitations

- [ ] Asyncify unwinding across image boundaries does not work yet.
      Extension libraries should be Asyncified with `--pass-arg=asyncify-relocatable` after linking.
- [ ] `.so` files must be visible at runtime.
      This is because CRuby checks the existence of `.so` files at runtime before `dlopen`ing them.
      We need to implement a way to bypass this check.

## Build

```console
$ make check
(snip)
wasmtime run --wasm component-model --dir ./::/ build/ruby.wasm -I build/ruby/.ext/wasm32-wasi -e 'require "stringio.so"; puts StringIO.new'
`RubyGems' were not loaded.
`error_highlight' was not loaded.
`did_you_mean' was not loaded.
`syntax_suggest' was not loaded.
#<StringIO:0x02275edc>
```
