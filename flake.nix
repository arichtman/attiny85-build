{
  description = "blg";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  outputs = {
    self,
    nixpkgs,
    rust-overlay
  }: let
    # Should work with other targets, but not tested.
    supportedSystems = ["x86_64-linux"];
    # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    # forAllSystems = { x86_64-linux = "x86_64-linux";};
    # Nixpkgs instantiated for supported system types.
    # But forAllSystems is an attribute set, not a function?
    nixpkgsFor = forAllSystems (
      # function that takes in 1 argument called "system"
      system:
        # Imports nixpkgs with some overrides?
        import nixpkgs {
          inherit system;
          # Here we're providing the Rust toolchain overlay thing, pretty standard.
          # But we're supposed to mode it to before this import of nixpkgs?
          # Or the other option is to apply overlays over the "package"?
          overlays = [ rust-overlay.overlays.default self.overlays.default ];
        }
    );
  in {
    overlays.default = final: prev: {
      rustToolchain =
        let
          rust = prev.rust-bin;
        in
        if builtins.pathExists ./rust-toolchain.toml then
          rust.fromRustupToolchainFile ./rust-toolchain.toml
        else if builtins.pathExists ./rust-toolchain then
          rust.fromRustupToolchainFile ./rust-toolchain
        else
          rust.stable.latest.default.override {
            extensions = [ "rust-src" "rustfmt" ];
          };
    };
    devShells = forAllSystems (system: let
      pkgs = nixpkgsFor.${system};
    in {
      default = pkgs.mkShell {
        buildInputs = with pkgs; [
          rustToolchain
          openssl
          pkg-config
          cargo-deny
          cargo-edit
          cargo-watch
          rust-analyzer
          micronucleus
          pkgs.pkgsStatic.pkgsCross.avr.buildPackages.gcc
        ];
        env = {
          # Required by rust-analyzer
          RUST_SRC_PATH = "${pkgs.rustToolchain}/lib/rustlib/src/rust/library";
          # RUSTC_BOOTSTRAP=1 is necessary because this target has not been fully stabilized yet and is still subject to change, you may need to make changes to stay compatible with future Rust compilers.
          RUSTC_BOOTSTRAP= 1;
        };
      };
    });
  };
}

