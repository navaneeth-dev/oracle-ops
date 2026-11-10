{
  description = "NixOS hosts outside the Kubernetes clusters";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      disko,
      sops-nix,
      ...
    }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.hostdzire6tb = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
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
