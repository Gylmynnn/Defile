.PHONY: run, gen

run:
	@cargo build --release --manifest-path rust/Cargo.toml
	@flutter run

gen:
	@flutter_rust_bridge_codegen generate
