{ pkgs, config, lib, ... }:
with lib;
let
  cfg = config.services.goatcounter;

  postgres = cfg.dbBackend.postgresql;
  sqlite = cfg.dbBackend.sqlite;

  postgresEnable = postgres != null;
  sqliteEnable = sqlite != null;

  cfgApache = config.services.apache;
  cfgNginx = config.services.nginx;

  urlOverride = postgres.url != null || postgres.urlFile != null;
in
{
  options.services.goatcounter =
    {
      enable = mkEnableOption "Enable goatcounter.";

      package = mkOption {
        description = "goatcounter package to use.";
        default = pkgs.goatcounter;
        type = types.package;
      };

      user = mkOption {
        description = "GoatCounter runtime user and PostgreSQL database user.";
        default = "goatcounter";
        type = types.str;
      };

      group = mkOption {
        description = "GoatCounter runtime group.";
        default = "goatcounter";
        type = types.str;
      };

      dataDir = mkOption {
        description = ''
          Path to goatcounter data directory, currently only stores the SQLite database.
        '';
        default = "/var/lib/goatcounter";
        type = types.str;
      };

      tls = mkOption {
        description = ''
          Whether to enable TLS with acme or a static certificate and keyfile.
          The certificate and keyfile must be in one file.
        '';
        default = false;
        type = with types; oneOf [ bool str ];
        example =
          ''
            true # enable TLS with ACME
            false # disable TLS
            "path/to/file.pem" # enable TLS with file
          '';
        apply = x:
          if isString x then
            "-tls " + x + ",rdr"
          else if x then
            "-tls acme,rdr"
          else
            "-tls http";
      };

      listenPort = mkOption {
        description = ''
          On which port will GoatCounter listen on, if null its left up to GoatCounter
          to decide.
        '';
        type = with types; nullOr str;
        default = "*:80";
        apply = x:
          if x != null then
            "-listen " + x
          else
            "";
      };

      publicPort = mkOption {
        description = ''
          Port your site is publicly accessible on. Only needed if it's
          not 80 or 443.
        '';
        type = with types; nullOr str;
        default = null;
        apply = x:
          if x != null then
            "-public-port " + x
          else
            "";
      };

      automigrate = mkOption {
        description = ''
          Automatically run all pending migrations on startup.
        '';
        type = types.bool;
        default = false;
        apply = x:
          optionalString x "-automigrate";
      };

      smtp = mkOption {
        description = ''
          SMTP server, as URL (e.g. "smtp://user:pass@server").

          A special value of "stdout" means no emails will be sent and
          emails will be printed to stdout only. This is the default.

          If this is blank emails will be sent without using a relay; this
          should work fine, but deliverability will usually be worse (i.e.
          it will be more likely to end up in the spam box). This usually
          requires rDNS properly set up, and GoatCounter will *not* retry
          on errors. Using stdout, a local smtp relay, or a mailtrap.io box
          is probably better unless you really know what you're doing.
        '';
        type = types.str;
        default = "stdout";
        apply = x:
          "-smtp " + x;
      };

      errors = mkOption {
        description = ''
          What to do with errors; they're always printed to stderr.

          mailto:to_addr[,from_addr]  Email to this address; the
                                      from_addr is optional and sets the
                                      From: address. The default is to
                                      use the same as the to_addr.

          If <literal>null</literal> then print to stderr only.
        '';
        type = with types; nullOr str;
        default = null;
        apply = x:
          if x != null then
            "-errors " + x
          else
            "";
      };

      emailFrom = mkOption {
        description = ''
          From: address in emails.
        '';
        type = types.str;
        apply = x:
          "-email-from " + x;
      };

      ensureSites = mkOption {
        description = ''
          Which sites to create on first startup. This module will never
          create/update/delete anything upon subsequent starts.
        '';
        type = types.listOf (types.submodule
          {
            options = {
              vhost = mkOption {
                description = ''
                  Which hostname will this site be accessed from, goatcounter differentiates
                  between sites with the HOST header. Not for login though.
                '';
                type = types.str;
              };

              link = mkOption {
                description = ''
                  Multiple vhosts can be linked together, with one master and multiple links,
                  to it. If this is set, <option>email</option> and
                  <option>password</option>/<option>passwordFile</option> have no effect.
                '';
                default = null;
                type = with types; nullOr str;
              };

              email = mkOption {
                description = ''
                  Email used for logging in.
                '';
                default = null;
                type = with types; nullOr str;
              };

              password = mkOption {
                description = ''
                  Password used for logging in, prefer <option>passwordFile</option> as it
                  doesn't make the password world-readable in the Nix store.
                '';
                default = null;
                type = with types; nullOr str;
              };
              passwordFile = mkOption {
                description = ''
                  Password file, containing the password for logging in, read at runtime.
                '';
                default = null;
                type = with types; nullOr str;
              };
            };
          });
        default = [];
      };

      dbBackend = mkOption {
        description = ''
          Which database backend should be used.
          The options in here can be thought of enums with associated data.
        '';
        default = { sqlite = {}; };
        type = types.submodule
          {
            options =
              {
                sqlite = mkOption {
                  description = ''
                    Enable and configure the SQLite database backend.
                  '';
                  default = {};
                  type = with types;
                    nullOr (submodule
                      {
                        options =
                          {
                            path = mkOption {
                              description = "Path to SQLite database file.";
                              type = str;
                              default = "${cfg.dataDir}/db.sqlite3";
                            };

                            config = mkOption {
                              description = ''
                                Key value pair options passed to the SQLite backend.
                              '';
                              type = attrsOf (oneOf [ str int ]);
                              default = {
                                _busy_timeout = 200;
                                _journal_mode = "wal";
                                cache = "shared";
                              };
                              apply = x:
                                concatStringsSep "&" (mapAttrsToList (n: v:
                                  n + "=" + (toString v)
                                ) x);
                            };
                          };
                      });
                };

                postgresql = mkOption {
                  description = ''
                    Enable and configure the PostgreSQL databse backend.
                  '';
                  default = null;
                  type = with types;
                    nullOr (submodule
                      {
                        options = {
                          url = mkOption {
                            description = ''
                            Fully override the connection URL and disable PostgreSQL
                            database auto-setup.
                          '';
                            default = null;
                            type = with types; nullOr str;
                          };

                          urlFile = mkOption {
                            description = ''
                            Fully override the connection URL from a file and disable
                            PostgreSQL database auto-setup.
                          '';
                            default = null;
                            type = with types; nullOr str;
                          };
                        };
                      });
                };
              };
          };
        example = literalExample
          ''
            { sqlite = {};
              postgresql = {};
            }
            # or
            { postgresql =
              { # configuration options ...
              };
              sqlite = null;
            }
          '';
      };

      dbOption = mkOption {
        description =
          ''
            The generated db command which specifies which DB to use by goatcounter.
          '';
        type = types.str;
        default =
          "-db " +
          (if postgresEnable && !urlOverride then
            "'postgresql://${cfg.user}:@/goatcounter?sslmode=disable&host=/run/postgresql'"
           else if postgresEnable && urlOverride then
             if postgres.url != null then
               "'${postgres.url}'"
             else
               "'$(<${postgres.urlFil})'"
           else
             "'sqlite://${sqlite.path}${optionalString (sqlite.config != "") ("?" + sqlite.config)}'");
        readOnly = true;
      };
    };

  config = mkIf cfg.enable {
    systemd.services.goatcounter =
      { description = "goatcounter server";

        wantedBy = [ "multi-user.target" ];
        after = optional postgresEnable "postgresql.service";

        preStart = optionalString (postgresEnable && !urlOverride) ''
          if ! [ -e /var/lib/goatcounter/.db-created ]; then
            ${cfg.package}/bin/goatcounter db schema-pgsql | ${config.services.postgresql.package}/bin/psql
            touch /var/lib/goatcounter/.db-created
          fi
        '' +
        optionalString sqliteEnable ''
          if ! [ -e /var/lib/goatcounter/.db-created ]; then
            ${cfg.package}/bin/goatcounter db ${cfg.dbOption} newdb -createdb
            touch /var/lib/goatcounter/.db-created
          fi
        '' +
        ''
          if ! [ -e /var/lib/goatcounter/.sites.created ]; then
            ${
              concatMapStringsSep "\n"
                (s:
                  if s.link == null then
                    ''
                      ${cfg.package}/bin/goatcounter db ${cfg.dbOption} create sites \
                        -vhost=${s.vhost} -user.email=${s.email} -user.password=${s.password}
                    ''
                  else
                    ''
                      ${cfg.package}/bin/goatcounter db ${cfg.dbOption} create sites \
                        -vhost=${s.vhost} -link=${s.link}
                    ''
                ) cfg.ensureSites
            }
            touch /var/lib/goatcounter/.sites.created
          fi 
        '';

        serviceConfig = mkMerge [
          { Restart   = "always";
            Type      = "simple";
            ExecStart =
              let
                inherit (cfg) tls listenPort publicPort automigrate smtp emailFrom errors;

                conf = "${tls} ${listenPort} ${publicPort} ${automigrate} ${smtp} ${emailFrom} ${errors} ${cfg.dbOption}";
              in pkgs.writeShellScript "goatcounter-start"
                ''
                  ${cfg.package}/bin/goatcounter serve ${conf}
                '';

            User = cfg.user;
            Group = cfg.group;
            AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
          }
          (mkIf (cfg.dataDir == "/var/lib/goatcounter") {
            StateDirectory = "goatcounter";
            StateDirectoryMode = "0700";
          })
        ];
      };

    services.postgresql = mkIf postgresEnable
      {
        enable = mkDefault true;
        package = pkgs.postgresql_12;
        ensureDatabases = [ "goatcounter" ];
        ensureUsers =
          [ { name = cfg.user;
              ensurePermissions =
                { "DATABASE \"goatcounter\"" = "ALL PRIVILEGES";
                };
            }
          ];
      };

    users = mkIf (cfg.user == "goatcounter" && cfg.group == "goatcounter")
      {
        users.goatcounter =
          { uid = 319;
            isSystemUser = true;
            group = "goatcounter";
          };

        groups.goatcounter =
          { gid = 319;
          };
      };

    assertions =
      [ { assertion =
            count
              (x: x != null)
              (mapAttrsToList nameValuePair cfg.dbBackend)
            == 1;
          message = "goatcounter - Exactly one database backend has to be enabled.";
        }
        { assertion =
            if cfg.dbBackend.postgresql != null then
              with cfg.dbBackend.postgresql;
              (url == null && urlFile != null) ||
              (url != null && urlFile == null) ||
              (url == null && urlFile == null)
            else
              true;
          message = "goatcounter - You can't both override the PostgreSQL URL with a string and a file path.";
        }
        { assertion =
            foldr (x: acc: acc && x) true
            (map
              (s:
                (s.link != null && s.password == null && s.passwordFile == null)
                || (s.link == null && s.password == null && s.passwordFile != null)
                || (s.link == null && s.password != null && s.passwordFile == null)
              ) cfg.ensureSites);
          message = "goatcounter - either `ensureSites.<site>.password` or `passwordFile` must be set if `ensureSites.<site>.link` is not set, when it set both must be `null`.";
        }
        { assertion =
            foldr (x: acc: acc && x) true
              (map
                (s:
                  (s.link != null && s.email == null)
                  || (s.link == null && s.email != null)
                ) cfg.ensureSites);
          message = "goatcounter - when `ensureSites.<site>.link` is set, `email` must be null, when not, then not.";
        }
      ];
  };
}
