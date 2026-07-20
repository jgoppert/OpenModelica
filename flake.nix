{
  description = "OpenModelica compiler and simulation runtimes";

  inputs = {
    self.submodules = true;
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      revision = self.shortRev or self.dirtyShortRev or "unknown";
      lastModifiedDate = self.lastModifiedDate or "19700101";
      version = "unstable-${builtins.substring 0 4 lastModifiedDate}-${
        builtins.substring 4 2 lastModifiedDate
      }-${builtins.substring 6 2 lastModifiedDate}";
      mkOpenModelica = pkgs: pkgs.callPackage ./nix/package.nix { inherit src version revision; };
      src = self;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          openmodelica = mkOpenModelica pkgs;
        in
        {
          inherit openmodelica;
          default = openmodelica;
        }
      );

      overlays.default = final: _prev: {
        openmodelica = mkOpenModelica final;
      };

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/omc";
          meta.description = "Run the OpenModelica compiler";
        };
      });

      checks = forAllSystems (system: {
        inherit (self.packages.${system}) openmodelica;
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.openmodelica ];
            packages = [ pkgs.ccache ];
          };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
