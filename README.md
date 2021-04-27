# nix-collectiveaccess

An attempt to package [CollectiveAccess](https://www.collectiveaccess.org/)
[providence](https://github.com/collectiveaccess/providence) as a Docker image
with [nix](https://nixos.org/).

## Status

This is a WIP experiment

## Building

Right now I'm focusing on building a docker image that will serve providence,
but will connect to an 'outside' mariadb instance for the database.

You can start it with:

```
docker run -p 8080:8080 $(docker load < $(nix-build build.nix) | cut -d " " -f 3) 
```

and then visit https://localhost:8080
