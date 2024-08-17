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

    # Nixpkgs instantiated for supported system types.
    nixpkgsFor = forAllSystems (system: import nixpkgs {inherit system;
    overlays = [ rust-overlay.overlays.default self.overlays.default ];
    });
  in {
    packages = forAllSystems (system: let
      pkgs = nixpkgsFor.${system}.pkgsStatic;
    in {
    });

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
          pkgsCross.avr.buildPackages.gcc
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

