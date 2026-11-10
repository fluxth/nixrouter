{
  description = "NixOS Router";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      sops-nix,
      ...
    }@inputs:
    {
      nixosConfigurations.nixrouter = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hardware-configuration.nix
          ./configuration.nix
          sops-nix.nixosModules.sops
        ];
      };
    };
}
