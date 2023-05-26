FROM fedora:37
LABEL maintainer=woodwardsh
ARG SVN_LOGIN
ARG SVN_PW

ENV HOME=/home/app
ENV MODEL_VERSION=1_2_1
ENV CCSMPATH=${HOME}/cesm/${MODEL_VERSION}
ENV CCSMSHARED=${CCSMPATH}/shared
ENV CCSMCASES=${CCSMSHARED}/cases
ENV CCSMROOT=${CCSMPATH}/src
ENV MAX_TASKS_PER_NODE=16
ENV OMPI_ALLOW_RUN_AS_ROOT=1
ENV OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
WORKDIR ${HOME}

# --- Install dependencies (layer shared with rocke3d image) ---
RUN dnf install -y gcc gcc-gfortran git nano wget which xz netcdf.x86_64 netcdf-fortran.x86_64 netcdf-devel.x86_64 netcdf-fortran-devel.x86_64 openmpi.x86_64 openmpi-devel.x86_64 'perl(File::Copy)'

# Ensure mpif90 in path
ENV PATH=$PATH:/usr/lib64/openmpi/bin

# --- Install CESM1.2 specific dependencies ---
RUN dnf install -y cmake g++ hostname m4 svn task-spooler 'perl(English)' 'perl(FindBin)' 'perl(File::Compare)' 'perl(File::Copy)' 'perl(Switch)' 'perl(XML::LibXML)'
RUN wget https://parallel-netcdf.github.io/Release/pnetcdf-1.12.3.tar.gz && \
    tar -xf pnetcdf-1.12.3.tar.gz && \
    cd pnetcdf-1.12.3 && \
    ./configure --prefix=/usr/local --with-mpi=/usr/lib64/openmpi && \
    make && make -j2 install && \
    cd .. && \
    rm pnetcdf-1.12.3.tar.gz

# --- Download CESM1.2.1 ---
# NB config_machines/config_compilers.xml is broken, so use ExoCAM ones even if not using ExoCAM
RUN svn co https://svn-ccsm-models.cgd.ucar.edu/cesm1/release_tags/cesm${MODEL_VERSION} ${CCSMROOT} --trust-server-cert --username ${SVN_LOGIN} --password ${SVN_PW} || true && \
    cd ${CCSMROOT} && \
    sed -i "s|http://parallelio.googlecode.com/svn/trunk_tags/pio1_7_2/pio|https://github.com/NCAR/ParallelIO.git/tags/pio1_7_4/pio|" SVN_EXTERNAL_DIRECTORIES && \
    svn propset svn:externals -F SVN_EXTERNAL_DIRECTORIES . && \
    cd tools/cprnc && \
    sed -i "s|http://parallelio.googlecode.com/svn/genf90/trunk_tags/genf90_130402|http://github.com/PARALLELIO/genf90/tags/genf90_130402|" SVN_EXTERNAL_DIRECTORIES && \
    svn propset svn:externals -F SVN_EXTERNAL_DIRECTORIES . && \
    cd ../.. && \
    svn update --trust-server-cert --username ${SVN_LOGIN} --password ${SVN_PW} --non-interactive

# --- Patch CESM ---
# See https://github.com/storyofthewolf/ExoCAM/blob/main/cesm1.2.1/instructions/computecanada_instructions.txt
# Additionally, check additional path for netcdf.mod in pio
RUN cd ${CCSMROOT} && \
    sed -i "s|foreach my \$model qw(\(.*\))|foreach my \$model (qw(\1))|" scripts/ccsm_utils/Case.template/ConfigCase.pm && \
    sed -i "s|\\\\\$ENV|&\\\|" scripts/ccsm_utils/Case.template/ConfigCase.pm && \
    sed -i "s|foreach my \$model qw(\(.*\))|foreach my \$model (qw(\1))|" scripts/ccsm_utils/Tools/cesm_setup && \
    sed -i "s|foreach my \$model qw(\(.*\))|foreach my \$model (qw(\1))|" models/drv/bld/build-namelist && \
    sed -i "305i # Note - \$USER is not in the config_definition.xml file - it is only in the environment\n\$xmlvars{'USER'} = \$ENV{'USER'};\nunshift @INC, \"\$CASEROOT/Tools\";\nrequire XML::Lite;\nrequire SetupTools;\nmy %xmlvars = ();\nSetupTools::getxmlvars(\$CASEROOT, \%xmlvars);\nforeach my \$attr (keys %xmlvars) {\n\t\$xmlvars{\$attr} = SetupTools::expand_env_var(\$xmlvars{\$attr}, \%xmlvars);\n}" models/drv/bld/build-namelist && \
    sed -i "320,327d" models/drv/bld/build-namelist && \
    sed -i "s|\$NETCDF_PATH/include/netcdf.mod|$NETCDF_PATH/lib64/gfortran/modules/netcdf.mod \&\& test ! -f &|" models/utils/pio/configure

# --- TODO: Clone ExoCAM and ExoRT & install ---
# Also fix invalid XML caused by double hyphens `--` inside comments
RUN git clone https://github.com/storyofthewolf/ExoRT.git
RUN git clone https://github.com/storyofthewolf/ExoCAM.git && \
    cp ExoCAM/cesm1.2.1/ccsm_utils_files/{config_machines,config_compilers,env_mach_specific,mkbatch}.* ${CCSMROOT}/scripts/ccsm_utils/Machines && \
    sed -i "s|<\!-- complete path to the 'scratch'|complete path to the 'scratch'|" ${CCSMROOT}/scripts/ccsm_utils/Machines/config_machines.xml && \
    sed -i "s| ->| -->|" ${CCSMROOT}/scripts/ccsm_utils/Machines/config_machines.xml && \
    sed -i "s|------------------------------------------------------------------------||" ${CCSMROOT}/scripts/ccsm_utils/Machines/config_compilers.xml && \
    sed -i "s/--\(trace\|trap\|pca\|chk\)/- -\1/" ${CCSMROOT}/scripts/ccsm_utils/Machines/config_compilers.xml && \
    sed -i "s|<\!--  -g | -g |" ${CCSMROOT}/scripts/ccsm_utils/Machines/config_compilers.xml
    #&& \
    # cp ExoCAM/cesm1.2.1/ccsm_utils_files/config_compsets.xml ${CCSMROOT}/scripts/ccsm_utils/Case.template && \
    # cp ExoCAM/cesm1.2.1/ccsm_utils_files/namelist_definition.xml ${CCSMROOT}/models/atm/cam/bld/namelist_files
    # find ExoCAM/cesm1.2.1/configs/ -type f -exec sed -i -e "s|/gpfsm/dnb53/etwolf/models|\$ENV{HOME}|" {} \;
    # find ExoRT/3dmodels/*/sys_rootdir.F90 -type f -exec sed -i "9i   ! Machine: docker\n  character(len=256), parameter :: exort_rootdir = '$ENV{HOME}/ExoRT/'\n" {} \;

# --- Create directories ---
RUN mkdir -p ${CCSMSHARED}/{baseline,cases,input,output,tests}

# --- Add "docker" machine/compiler config ---
COPY src/ccsm_utils_files/mkbatch.docker ${CCSMROOT}/scripts/ccsm_utils/Machines/mkbatch.docker
COPY src/ccsm_utils_files/env_mach_specific.docker ${CCSMROOT}/scripts/ccsm_utils/Machines/env_mach_specific.docker
COPY src/setup/_config_machines_docker.xml setup/_config_machines_docker.xml
COPY src/setup/_config_compilers_docker.xml setup/_config_compilers_docker.xml
COPY src/setup/add_docker_config.ps setup/add_docker_config.ps
RUN perl setup/add_docker_config.ps && \
    chmod 755 ${CCSMROOT}/scripts/ccsm_utils/Machines/mkbatch.docker
