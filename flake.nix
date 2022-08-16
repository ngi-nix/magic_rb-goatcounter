{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
  };

  outputs = { self, nixpkgs, ... }:
    with nixpkgs.lib;
    let
      supportedSystems = [ "x86_64-linux" "i686-linux" "aarch64-linux" ];
      forAllSystems' = systems: fun: nixpkgs.lib.genAttrs systems fun;
      forAllSystems = forAllSystems' supportedSystems;

      systemModule = dbBackends:
        ({ ... }:
          {
            nixpkgs.overlays = [ self.overlays.goatcounter ];

            imports = [ self.nixosModule ];

            services.goatcounter = {
              enable = true;

              emailFrom = "root@example.org";
              dbBackend =
                { sqlite = {};
                  postgresql = null;
                };

              ensureSites =
                [ { vhost = "example.org";
                    email = "root@example.org";
                    password = "toortoor";
                  }
                ];
            };
          });
    in
      {
        overlays.goatcounter =
          final: prev:
          {
            goatcounter = final.python3Packages.callPackage ./goatcounter.nix {};
          };

        overlay = self.overlays.goatcounter;

        packages = forAllSystems (system:
          let
            pkgs = import nixpkgs
              { inherit system;
                overlays = mapAttrsToList (_: id) self.overlays;
              };
          in
            {
              inherit (pkgs) goatcounter;
            }
        );

        defaultPackage = forAllSystems (system:
          self.packages.${system}.goatcounter
        );

        apps = mapAttrs (_: v:
          mapAttrs (_: a:
            {
              type = "app";
              program = a;
            }
          ) v
        ) self.packages;

        defaultApp = mapAttrs (_: v:
          v.goatcounter
        ) self.apps;

        devShell = forAllSystems (system: self.packages.${system}.goatcounter);

        nixosModules.goatcounter = import ./module.nix;

        nixosModule = self.nixosModules.goatcounter;

        nixosConfigurations =
          let
            baseConfig = dbBackends:
              nixosSystem {
                system = "x86_64-linux";

                modules = [
                  (systemModule dbBackends)
                  ({ ... }: { boot.isContainer = true; })
                ];
              };
          in
            { containerSQLite = baseConfig { sqlite = {}; postgresql = null; };
              containerPostgreSQL = baseConfig { sqlite = null; postgresql = {}; }; 
            };

        nixosTests =
          { goatcounterSQLite = forAllSystems (system:
              import "${nixpkgs}/nixos/tests/make-test-python.nix"
                ({ pkgs, ... }: {
                  name = "help";

                  nodes.machine = systemModule
                    { sqlite = {};
                      postgresql = null;
                    };

                  testScript =
                    ''
                  start_all()

                  machine.wait_for_unit("goatcounter.service")
                  machine.wait_for_open_port(80)
                  machine.succeed("${pkgs.curl}/bin/curl http://localhost/")
                '';
                }) { inherit system; }
            );

            goatcounterPostgreSQL = forAllSystems (system:
              import "${nixpkgs}/nixos/tests/make-test-python.nix"
                ({ pkgs, ... }: {
                  name = "help";

                  nodes.machine = systemModule
                    { sqlite = null;
                      postgresql = {};
                    };

                  testScript =
                    ''
                  start_all()

                  machine.wait_for_unit("goatcounter.service")
                  machine.wait_for_open_port(80)
                  machine.succeed("${pkgs.curl}/bin/curl http://localhost/")
                '';
                }) { inherit system; }
            );
          };

        hydraJobs = forAllSystems (system: {
          build = self.defaultPackage.${system};
          test =
            { sqlite = self.nixosTests.goatcounterSQLite.${system};
              postgresql = self.nixosTests.goatcounterPostgreSQL.${system};
            };
        });
      };
}
