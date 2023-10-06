{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.disko = {
    url = "github:nix-community/disko";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.nuenv = {
    url = "github:DeterminateSystems/nuenv";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, nuenv, ... }: let
    overlays = [ nuenv.overlays.default ];
    systems = [ "x86_64-linux" "aarch64-linux" ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
      inherit system;
      pkgs = import nixpkgs { inherit overlays system; };
    }); 
  in {
    nixosModules.aio = { pkgs, config, lib, ... }: {
      options.fvtt-multi = with lib; {
        enable =
          mkEnableOption "enable Khionu's Multitenant Foundry setup";
        availableInstanceDomains = mkOption {
          type = types.listOf types.string;
          description = mdDoc "Domains that instances can be subdomains of";
        };
        adminDomain = mkOption {
          type = types.string;
          description = mdDoc "Domain that admin services will be of. Must have a wildcard record";
        };
        instanceDataset = mkOption {
          type = types.string;
          description = mdDoc "The ZFS dataset underwhich this flake will store Foundry instances.";
        };
        enableNomadUi = mkOption {
          type = types.bool;
          description = mdDoc "Enable the Nomad UI";
          default = true;
        };
        enableNomadAcl = mkOption {
          type = types.bool;
          description = mdDoc "Enable the Nomad ACL - highly recommended to leave this on";
          default = true;
        };
      };

      config = lib.mkIf config.fvtt-multi.enable {
        services.nomad = {
          enable = true;
          settings = {
            ui.enabled = config.fvtt-multi.enableNomadUi;
            acl.enabled = config.fvtt-multi.enableNomadAcl;
            server = {
              enabled = true;
              bootstrap_expect = 1;
            };
            client.enabled = true;
          };
        };

        environment.etc."fvtt-mt/provided_settings.json" = {
          text = builtins.toJSON config.fvtt-multi;
          mode = "0444";
        };
        environment.etc."fvtt-mt/Caddyfile.tpl" = {
          source = ./services/caddy.tpl;
          mode = "0444";
        };
        environment.etc."fvtt-mt/nomad/services/caddy.nomad.hcl" = {
          source = ./services/caddy.nomad.hcl;
          mode = "0444";
        };

        systemd.services.bootstrap-nomad = {
          enable = true;
          after = [ "nomad.service" ];
          wantedBy = [ "multi-user.target" ];
          description = "Ensure we have deployed critical Nomad services";
          serviceConfig.Type = "oneshot";
          script = "${self.packages."x86_64-linux".bootstrap-nomad}/bin/bootstrap-nomad";
        };
      };
    };
    packages = forAllSystems ({ pkgs, system }: {
      bootstrap-nomad = pkgs.nuenv.writeScriptBin {
        name = "bootstrap-nomad";
        script = ''
          let config = open /etc/fvtt-mt/provided_settings.json

          if not (/root/nomad/bootstrap | path exists) {
            mkdir /root/nomad
            ${pkgs.nomad}/bin/nomad acl bootstrap |
              lines | parse '{name} = {value}' | str trim | transpose -rd |
              to json | save -f /root/nomad/bootstrap
          }

          $env.NOMAD_TOKEN = (/root/nomad/bootstrap | open | get "Secret ID")


          if ($config | get "nomadEnableAcl") {
            let policies = nomad acl policy list -json | from json
          }
        '';
      };
    });
  };
}
