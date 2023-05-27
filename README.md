# ExoCAM (CESM1.2) Docker Image

[Docker](https://www.docker.com/) image to install and run a containerised [ExoCAM](https://github.com/storyofthewolf/ExoCAM) (CESM1.2) on Fedora.


## Useful links

* [CESM1.2 User Guide](https://www2.cesm.ucar.edu/models/cesm1.2/cesm/doc/usersguide/ug.pdf)
* [CESM1.2 Website](https://www2.cesm.ucar.edu/models/cesm1.2/tags/index.html)
* [ExoCAM User Guide](https://github.com/storyofthewolf/ExoCAM/blob/master/cesm1.2.1/instructions/general_instructions.txt)
* [gcc/gfortran docs](https://gcc.gnu.org/onlinedocs/gfortran/index.html#SEC_Contents)
* [Docker build help](https://docs.docker.com/engine/reference/commandline/build/)
* [Docker run help](https://docs.docker.com/engine/reference/commandline/run/)


## Installation & running via published image

* [Install Docker desktop](https://www.docker.com/get-started)
* Ensure Docker desktop is running
* Download published image:

```
docker pull woodwardsh/exocam:latest
```

* Run container, noting the mounting of local dir `shared` to container `/home/app/cesm/1_2_1/shared` for shared storage of model cases, input, scratch, and output:

```
docker run -it --rm --volume=${PWD}/shared:/home/app/cesm/1_2_1/shared woodwardsh/exocam:latest

# Options:
# -it       interactive && TTY (starts shell inside container)
# --rm      delete container on exit
# --volume  mount local directory inside container
```


### Podman

```
podman run -it --rm -v ${PWD}/shared:/home/app/cesm/1_2_1/shared --security-opt label=disable woodwardsh/exocam:latest
```


## Installation & running via locally built image


* [Register for CESM repository access](https://www2.cesm.ucar.edu/models/register/)
* Clone repo & navigate inside:

```
git clone git@github.com:hannahwoodward/docker-exocam.git && cd docker-exocam
```

* Build image from Dockerfile, passing in CESM repo credentials as build args (~15 min):

```
docker build --build-arg SVN_LOGIN= --build-arg SVN_PW= -t exocam .

# Or, if debugging:

docker build  --build-arg SVN_LOGIN= --build-arg SVN_PW= -t exocam . --progress=plain --no-cache
```

* Run locally built container, noting the mounting of local dir `shared` to container `/home/app/cesm/1_2_1/shared` for shared storage of model baselines, cases, input, output, and tests:

```
docker run -it --rm --volume=${PWD}/shared:/home/app/cesm/1_2_1/shared exocam

# Options:
# -it       interactive && TTY (starts shell inside container)
# --rm      delete container on exit
# --volume  mount local directory inside container
# -w PATH   sets working directory inside container
```


## Usage

* Start docker container via `docker|podman run ...` as above
* In `MACH="docker"` xml config in `$CCSMROOT/scripts/ccsm_utils/Machines/config_machines.xml`, edit `GMAKE_J` and `MAX_TASKS_PER_NODE` to match your hardware resource


### CESM1.2.1 example

* In the container, run:

```
cd $CCSMROOT/scripts
./create_newcase -res f45_g37 -compset X -mach docker -case $CCSMCASES/test1
cd $CCSMCASES/test1
./cesm_setup
csh test1.build
csh test1.run
```

### ExoCAM example

* In the container, run (see [ExoCAM repo](https://github.com/storyofthewolf/ExoCAM/blob/main/cesm1.2.1/instructions/general_instructions.txt) for more detailed instructions):

```
cd $CCSMROOT/scripts
./create_newcase -res f45_f45 -mach docker -compset E2000C4AQI -case $CCSMCASES/exocam-aquaplanet
cd $CCSMCASES/exocam-aquaplanet
perl xmlchange CAM_CONFIG_OPTS="-nlev 40 -phys cam4 -usr_src $HOME/ExoRT/3dmodels/src.cam.n68equiv"
cp -r ~/ExoCAM/cesm1.2.1/configs/cam_aqua_fv/SourceMods/ .
cp -r ~/ExoCAM/cesm1.2.1/configs/cam_aqua_fv/namelist_files/* .
./cesm_setup
csh test1.build
csh test1.run
```


## Testing

* TODO

## Publishing image

```
docker login && docker tag exocam woodwardsh/exocam && docker push woodwardsh/exocam
```
