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
          pkgs.nvc
        ];
      };
    in {
      packages.${system}.default = vhdl-toolchain;

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          vhdl-toolchain
          pkgs.vhdl-ls
          pkgs.gtkwave
          python-env
        ];

        VUNIT_SIMULATOR = "nvc";
      };
    };
}
