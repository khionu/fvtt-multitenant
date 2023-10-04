{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs = { ... }: {
    nixosModules.fvtt-multitenant = { config, lib, ... }: {
      options.fvtt-multitenant.enable =
        lib.mkEnableOption "enable Khionu's Multitenant Foundry setup";

      config = lib.mkIf config.fvtt-multitenant.enable {
      };
    };
  };
}
