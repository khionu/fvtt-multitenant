{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.disko = {
    url = "github:nix-community/disko";
    follows = inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, disko, ... }: {
    nixosModules.aio = { config, lib, ... }: {
      options.fvtt-multitenant.enable =
        lib.mkEnableOption "enable Khionu's Multitenant Foundry setup";

      config = lib.mkIf config.fvtt-multitenant.enable {
        services.nomad.enable = true;
        services.nomad = {
          enable = true;
          extraSettingsPlugins = [
            pkgs.nomad-driver-podman
          ];
          settings = {
            server = {
              enabled = true;
              bootstrap_expect = 1;
            };
            client.enabled = true;
          };
        };
      };
    };
  };
}
