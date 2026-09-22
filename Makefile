.PHONY: run, gen

run:
	@flutter run

gen:
	@flutter_rust_bridge_codegen generate
