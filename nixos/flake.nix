{
  description = "NixOS hosts outside the Kubernetes clusters";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, disko, ... }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.hostdzire6tb = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          ./hosts/hostdzire
        ];
      };

      checks.${system}.garage =
        let
          pkgs = import nixpkgs {
            inherit system;
            # garage-webui's frontend is built with pnpm 9, which nixpkgs marks
            # insecure. It runs only at build time and is not in the output.
            config.permittedInsecurePackages = [ "pnpm-9.15.9" ];
          };
        in
        pkgs.testers.runNixOSTest ./tests/garage;
    };
}
