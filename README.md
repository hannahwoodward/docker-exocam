# ExoCAM (CESM1.2) Docker Image

[Docker](https://www.docker.com/) image to install and run a containerised ExoCAM (CESM1.2) on Fedora.


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

* Run container, noting the mounting of local dirs `{cases,output}` to container `/home/app/cesm/1_2_2_1/data/{cases,output}` for shared storage of model cases & output:

```
docker run -it --rm --volume=${PWD}/output:/home/app/cesm/1_2_2_1/data/output --volume=${PWD}/cases:/home/app/cesm/1_2_2_1/data/cases woodwardsh/exocam:latest

# Options:
# -it       interactive && TTY (starts shell inside container)
# --rm      delete container on exit
# --volume  mount local directory inside container
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

* Run locally built container

```
docker run -it --rm --volume=${PWD}/output:/home/app/cesm/1_2_2_1/data/output --volume=${PWD}/cases:/home/app/cesm/1_2_2_1/data/cases exocam

# Options:
# -it       interactive && TTY (starts shell inside container)
# --rm      delete container on exit
# --volume  mount local directory inside container
# -w PATH   sets working directory inside container
```


## Testing

* TODO

## Publishing image

```
docker login && docker tag exocam woodwardsh/exocam && docker push woodwardsh/exocam
```
