# nix-collectiveaccess

An attempt to package [CollectiveAccess](https://www.collectiveaccess.org/)
[providence](https://github.com/collectiveaccess/providence) as a Docker image
with [nix](https://nixos.org/).

## Status

This is a WIP experiment

## Using

If you just want to use the image, and not change any of the settings
or configuration in `build.nix`, you can fetch it from dockerhub:

```
$ docker pull docker.io/raboof/providence
```

Then create and populate the media directory:

```
$ mkdir -p /tmp/media/collectiveaccess/images
$ mkdir /tmp/media/collectiveaccess/tilepics
$ chmod a+rwx /tmp/media
$ chmod a+rwx /tmp/media/collectiveaccess
$ chmod a+rwx /tmp/media/collectiveaccess/images
$ chmod a+rwx /tmp/media/collectiveaccess/tilepics
```

and start the images:

```
$ docker-compose up
```

Then go to http://localhost:8080 to create the initial population for the database.

## Building

Right now I'm focusing on building a docker image that will serve providence,
but will connect to an 'outside' mariadb instance for the database.

You can start it with:

```
docker load < $(nix-build build.nix)
docker-compose up
```

and then visit https://localhost:8080
