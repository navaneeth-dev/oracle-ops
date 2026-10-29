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
    };
}
