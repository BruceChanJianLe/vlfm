{
  description = "Development environment with micromamba";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=release-24.05";
    nixpkgs20.url = "github:nixos/nixpkgs/release-20.03";
  };

  outputs = { self, nixpkgs, nixpkgs20 }:
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

        pkgs20 = import nixpkgs20 { inherit system; };
      });
    in
    {
      devShells = forAllSystems ({ pkgs, pkgs20 }: {
        default = pkgs.mkShell {
          buildInputs = [
            pkgs.gcc11
            pkgs.micromamba
            # CUDA toolkit
            pkgs.cudaPackages_11.cudatoolkit
            pkgs.cudaPackages_11.cuda_nvcc
            # cmake
            pkgs20.cmake

            pkgs.pkg-config
            pkgs.mesa
            pkgs.libGL
            pkgs.libGLU
            pkgs.zlib
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

            export CMAKE_POLICY_VERSION_MINIMUM=3.5
            export CMAKE_ARGS="-DCMAKE_POLICY_VERSION_MINIMUM=3.5"

            export CC=${pkgs.gcc11}/bin/gcc
            export CXX=${pkgs.gcc11}/bin/g++
            export LD=${pkgs.gcc11}/bin/ld

            # Start setting up vlfm
            micromamba create -n vlfm python=3.9 -y -c conda-forge
            micromamba activate vlfm
            pip install torch==1.12.1+cu113 torchvision==0.13.1+cu113 -f https://download.pytorch.org/whl/torch_stable.html
            pip install git+https://github.com/IDEA-Research/GroundingDINO.git@eeba084341aaa454ce13cb32fa7fd9282fc73a67 salesforce-lavis==1.0.2
            pip install -e '.[habitat]'
            git clone git@github.com:WongKinYiu/yolov7.git
          '';
        };
      });
    };
}
