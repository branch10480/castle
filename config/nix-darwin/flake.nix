{
  description = "toshiharuimaeda's nix-darwin + home-manager configuration (managed via homeshick castle)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, ... }:
    let
      username = "toshiharuimaeda";
      system = "aarch64-darwin";

      mkDarwin = hostname:
        nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = { inherit username hostname; };
          modules = [
            ./darwin.nix
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit username; };
              home-manager.users.${username} = import ./home.nix;
              networking.hostName = hostname;
              networking.computerName = hostname;
            }
          ];
        };
    in
    {
      darwinConfigurations = {
        "ToshiharunoMacBook-Pro" = mkDarwin "ToshiharunoMacBook-Pro";
        # default alias so `darwin-rebuild switch --flake .` works regardless of hostname
        default = mkDarwin "ToshiharunoMacBook-Pro";
      };
    };
}
