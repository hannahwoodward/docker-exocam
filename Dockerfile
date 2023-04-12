FROM fedora:latest
LABEL maintainer=woodwardsh
ARG SVN_LOGIN
ARG SVN_PW

ENV HOME=/home/app
ENV MODEL_VERSION=1_2_2_1
ENV CCSMPATH=${HOME}/cesm/${MODEL_VERSION}
ENV CCSMSHARED=${CCSMPATH}/shared
ENV CCSMCASES=${CCSMSHARED}/cases
ENV CCSMROOT=${CCSMPATH}/src
ENV MAX_TASKS_PER_NODE=2
ENV OMPI_ALLOW_RUN_AS_ROOT=1
ENV OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
WORKDIR ${HOME}

# --- Install dependencies (layer shared with rocke3d image) ---
RUN dnf install -y gcc gcc-gfortran git nano wget which xz netcdf.x86_64 netcdf-fortran.x86_64 netcdf-devel.x86_64 netcdf-fortran-devel.x86_64 openmpi.x86_64 openmpi-devel.x86_64 'perl(File::Copy)'

# Ensure mpif90 in path
ENV PATH=$PATH:/usr/lib64/openmpi/bin

# --- Install CESM1.2 specific dependencies ---
RUN dnf install -y cmake g++ hostname m4 svn task-spooler 'perl(English)' 'perl(XML::LibXML)' 'perl(FindBin)'
RUN wget https://parallel-netcdf.github.io/Release/pnetcdf-1.12.3.tar.gz && \
    tar -xf pnetcdf-1.12.3.tar.gz && \
    cd pnetcdf-1.12.3 && \
    ./configure --prefix=/usr/local --with-mpi=/usr/lib64/openmpi && \
    make && make -j2 install && \
    cd .. && \
    rm pnetcdf-1.12.3.tar.gz

# --- Download CESM ---
RUN svn co https://svn-ccsm-models.cgd.ucar.edu/cesm1/release_tags/cesm${MODEL_VERSION} ${CCSMROOT} --trust-server-cert --username ${SVN_LOGIN} --password ${SVN_PW}

# --- Patch CESM ---
# Update pio version
# https://bb.cgd.ucar.edu/cesm/threads/cesm-1-2-2-1-cesm_setup-module-issue-on-cheyenne.4680/page-2
RUN cd ${CCSMROOT}/models/utils && \
    rm -rf pio && \
    wget https://github.com/NCAR/ParallelIO/archive/refs/tags/pio1_8_14.tar.gz && \
    tar -xf pio1_8_14.tar.gz && \
    mv ParallelIO-pio1_8_14/pio ./pio && \
    rm -rf ParallelIO-pio1_8_14 pio1_8_14.tar.gz

# Patch FindNETCDF to include /lib64 directory when looking for netcdf in pio compilation
COPY src/ccsm_utils_files/CMake/FindNETCDF.cmake ${CCSMROOT}/scripts/ccsm_utils/CMake/FindNETCDF.cmake

# --- TODO: Clone ExoCAM and ExoRT ---
#RUN git clone https://github.com/storyofthewolf/ExoRT.git
#RUN git clone https://github.com/storyofthewolf/ExoCAM.git

# --- TODO: Copy ExoCam files over to CESM installation ---
#RUN cp ./ExoCAM/cesm1.2.1/ccsm_utils_files/{config_compilers,config_machines,mkbatch,env_mach_specific}.* ${CCSMROOT}/scripts/ccsm_utils/Machines && \
#    cp ./ExoCAM/cesm1.2.1/ccsm_utils_files/config_compsets.xml ${CCSMROOT}/scripts/ccsm_utils/Case.template && \
#    cp ./ExoCAM/cesm1.2.1/ccsm_utils_files/namelist_definition.xml ${CCSMROOT}/models/atm/cam/bld/namelist_files/namelist_definition.xml

# --- Create directories ---
RUN mkdir -p ${CCSMSHARED}/{cases,input,output,scratch}

# --- Add "docker" machine/compiler config ---
COPY src/ccsm_utils_files/mkbatch.docker ${CCSMROOT}/scripts/ccsm_utils/Machines/mkbatch.docker
COPY src/ccsm_utils_files/env_mach_specific.docker ${CCSMROOT}/scripts/ccsm_utils/Machines/env_mach_specific.docker
COPY src/setup/_config_machines_docker.xml setup/_config_machines_docker.xml
COPY src/setup/_config_compilers_docker.xml setup/_config_compilers_docker.xml
COPY src/setup/add_docker_config.ps setup/add_docker_config.ps
RUN perl setup/add_docker_config.ps && \
    chmod 755 ${CCSMROOT}/scripts/ccsm_utils/Machines/mkbatch.docker
# NB invalid XML in ExoCam config_machines.xml
