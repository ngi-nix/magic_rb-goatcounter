# pmbootstrap

- upsteam: https://gitlab.com/postmarketOS/pmbootstrap
- ngi-nix: https://github.com/ngi-nix/ngi/issues/198

GoatCounter is an open source web analytics platform available as a hosted service (free for non-commercial use) or self-hosted app. It aims to offer easy to use and meaningful privacy-friendly web analytics as an alternative to Google Analytics or Matomo.

> :warning: As most Flakes in `nig-ngi` this Flake is a **work in progress**!

## Using

In order to use this [flake](https://nixos.wiki/wiki/Flakes) you realistically need to be running [NixOS](https://nixos.org/) and then you can import a module that this flakes provides at `nixosModule`, but if you know what you're doing you can also run goatcounter manually with:

> :warning: You will need to setup the goatcounter config file and an appropriate database.

```
$ nix run github:ngi-nix/magic_rb-goatcounter
```

You can also enter a development shell with:

```
$ nix develop github:ngi-nix/magic_rb-goatcounter
```

For information on how to automate this process, please take a look at [direnv](https://direnv.net/).
