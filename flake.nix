{
  description = "Development environment with micromamba";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=release-24.05";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            cudaSupport = true;
          };
        };
      });
    in
    {
      devShells = forAllSystems ({ pkgs }: {
        default = pkgs.mkShell {
          buildInputs = [
            pkgs.micromamba
            # CUDA toolkit
            pkgs.cudaPackages_11.cudatoolkit
            pkgs.cudaPackages_11.cuda_nvcc
          ];

          shellHook = ''
            # Set up micromamba in the shell
            export MAMBA_ROOT_PREFIX="$PWD/.micromamba"
            mkdir -p "$MAMBA_ROOT_PREFIX"

            # Initialize micromamba for the current shell
            # This only works with bash shell as shellHook is bash
            CURR_SHELL=$(basename "$SHELL")
            eval "$(micromamba shell hook --shell $CURR_SHELL)"

            echo "Micromamba development environment"
            echo "Micromamba version: $(micromamba --version)"

            # Set CUDA environment variables
            export CUDA_PATH="${pkgs.cudaPackages_11.cudatoolkit}"
            export LD_LIBRARY_PATH="${pkgs.cudaPackages_11.cudatoolkit}/lib:$LD_LIBRARY_PATH"
            export EXTRA_LDFLAGS="-L${pkgs.cudaPackages_11.cudatoolkit}/lib"
            export EXTRA_CCFLAGS="-I${pkgs.cudaPackages_11.cudatoolkit}/include"

            echo "cuda version: $(nvcc --version)"
          '';
        };
      });
    };
}
