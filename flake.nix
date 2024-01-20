{
  description = "NSV stopwatch";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, poetry2nix, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        system = "${system}";
      };
      inherit (poetry2nix.lib.mkPoetry2Nix {
        inherit pkgs;
      }) mkPoetryPackages defaultPoetryOverrides;

      python-env = pkgs.python311.withPackages(ps: [
        (ps.buildPythonPackage rec {
          pname = "vunit-hdl";
          version = "4.7.0";
          src = pkgs.fetchFromGitHub {
            owner = "VUnit";
            repo = "vunit";
            rev = "v4.7.0";
            hash = "sha256-xhCPPnUXUdLg5kElbyJKW0tJOZMUoM1bV2siOsoz3Zs=";
          };

          doCheck = false;

          nativeBuildInputs = [
            ps.setuptoolsBuildHook
            ps.setuptools
            ps.pythonImportsCheckHook

            pkgs.ghdl # VHDL simulator needed for build/testing
            ps.pytest
          ];

          propagatedBuildInputs = [
            ps.colorama
          ];
        })
      ]);
      vhdl-toolchain = pkgs.symlinkJoin {
        name = "vhdl-toolchain";
        meta.mainProgram = "nvc";
        paths = [
          pkgs.ghdl
          # pkgs.nvc
        ];
      };
    in {
      packages.${system}.default = vhdl-toolchain;

      devShells.${system} = {
        docs = pkgs.mkShell {
          packages = [
            pkgs.pandoc
            pkgs.tectonic
            pkgs.inkscape
            (pkgs.python3.withPackages(ps: [
              ps.pandocfilters
            ]))
          ];
        };

        default = pkgs.mkShell {
          packages = [
            vhdl-toolchain

            (pkgs.rustPlatform.buildRustPackage rec {
                pname = "vhdl-ls";
                version = "0.77.0-patched";

                src = pkgs.fetchFromGitHub {
                  owner = "Rutherther";
                  repo = "rust_hdl";
                  rev = "return-new-line";
                  hash = "sha256-EYG6Rycnq9unTTVk9Iy6ivnbr8sT1U7vnNGnnZefSqk=";
                };

                cargoHash = "sha256-YkeepkJLq95e9X2v+1AxMBmT0q4ARJXA1WB89/KmTcY=";

                postPatch = ''
                  substituteInPlace vhdl_lang/src/config.rs \
                    --replace /usr/lib $out/lib
                '';

                postInstall = ''
                  mkdir -p $out/lib/rust_hdl
                  cp -r vhdl_libraries $out/lib/rust_hdl
                '';
            })
            pkgs.gtkwave
            python-env
          ];

          VUNIT_SIMULATOR = "nvc";
        };
      };
    };
}
