{
  description = "miri flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Systems, gets a list of systems, allows easy overriding
    systems.url = "github:nix-systems/default";
  };

  outputs = inputs: let
    eachSystem = inputs.nixpkgs.lib.genAttrs (import inputs.systems);
  in {
    devShells = eachSystem (system: let
      pkgs = import inputs.nixpkgs {
        inherit system;
      };
    in {
      default = with pkgs;
        mkShell {
          packages = [git rustup rustup-toolchain-install-master patchelf];

          shellHook = ''
            export PROJECT_ROOT=$(git rev-parse --show-toplevel)
            export PROJECT_NIX_DIR=$PROJECT_ROOT/etc/nix-dev-shell/.nix
            export CARGO_HOME=$PROJECT_NIX_DIR/cargo
            export RUSTUP_HOME=$PROJECT_NIX_DIR/rustup

            export PATH=$PATH:$RUSTUP_HOME/toolchains/miri/bin

            $PROJECT_ROOT/miri toolchain

            # Patch all rustup-downloaded ELF binaries to use the NixOS dynamic linker.
            INTERP="${pkgs.stdenv.cc.libc}/lib/ld-linux-x86-64.so.2"
            while IFS= read -r -d "" bin; do
              if [ "$(patchelf --print-interpreter "$bin" 2>/dev/null)" != "$INTERP" ]; then
                patchelf --set-interpreter "$INTERP" "$bin" 2>/dev/null || true
              fi
            done < <(find "$RUSTUP_HOME/toolchains/miri" -type f -executable -print0)
          '';
        };
    });
  };
}
