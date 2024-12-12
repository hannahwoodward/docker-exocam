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
# suppress error hwloc/linux: Ignoring PCI device with non-16bit domain.
# see https://github.com/open-mpi/hwloc/issues/354
ENV HWLOC_HIDE_ERRORS=2
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
# Notes:
# - github has removed svn support, so have to manually download gh externals (https://github.blog/changelog/2024-01-08-subversion-has-been-sunset/)
# - config_machines/config_compilers.xml is broken, so use ExoCAM ones even if not using ExoCAM
RUN svn co https://svn-ccsm-models.cgd.ucar.edu/cesm1/release_tags/cesm${MODEL_VERSION} ${CCSMROOT} --trust-server-cert --username ${SVN_LOGIN} --password ${SVN_PW} || true && \
    cd ${CCSMROOT}/models/utils && \
    wget https://github.com/MCSclimate/MCT/archive/refs/tags/MCT_2.8.3.tar.gz && \
    tar -xf MCT_2.8.3.tar.gz && \
    mv MCT-MCT_2.8.3 mct && \
    wget https://github.com/NCAR/ParallelIO/archive/refs/tags/pio1_7_4.tar.gz && \
    tar -xf pio1_7_4.tar.gz && \
    mv ParallelIO-pio1_7_4/pio . && \
    rm -r MCT_2.8.3.tar.gz ParallelIO-pio1_7_4 pio1_7_4.tar.gz && \
    cd ${CCSMROOT}/tools/cprnc && \
    wget https://github.com/PARALLELIO/genf90/archive/refs/tags/genf90_130402.tar.gz && \
    tar -xf genf90_130402.tar.gz && \
    mv genf90-genf90_130402 genf90 && \
    rm -r genf90_130402.tar.gz

# --- Patch CESM ---
# See https://github.com/storyofthewolf/ExoCAM/blob/main/cesm1.2.1/instructions/computecanada_instructions.txt
# Additionally, check additional path for netcdf.mod in pio
RUN cd ${CCSMROOT} && \
    sed -i "s|foreach my \$model qw(\(.*\))|foreach my \$model (qw(\1))|" scripts/ccsm_utils/Case.template/ConfigCase.pm && \
    sed -i "s|\\\\\$ENV|&\\\|" scripts/ccsm_utils/Case.template/ConfigCase.pm && \
    sed -i "s|foreach my \$model qw(\(.*\))|foreach my \$model (qw(\1))|" scripts/ccsm_utils/Tools/cesm_setup && \
    sed -i "s|(defined @date)|(@date)|" scripts/ccsm_utils/Tools/check_exactrestart.pl && \
    sed -i "s|foreach my \$model qw(\(.*\))|foreach my \$model (qw(\1))|" models/drv/bld/build-namelist && \
    sed -i "305i # Note - \$USER is not in the config_definition.xml file - it is only in the environment\n\$xmlvars{'USER'} = \$ENV{'USER'};\nunshift @INC, \"\$CASEROOT/Tools\";\nrequire XML::Lite;\nrequire SetupTools;\nmy %xmlvars = ();\nSetupTools::getxmlvars(\$CASEROOT, \\\%xmlvars);\nforeach my \$attr (keys %xmlvars) {\n\t\$xmlvars{\$attr} = SetupTools::expand_env_var(\$xmlvars{\$attr}, \\\%xmlvars);\n}" models/drv/bld/build-namelist && \
    sed -i "320,327d" models/drv/bld/build-namelist && \
    sed -i "s|\$NETCDF_PATH/include/netcdf.mod|$NETCDF_PATH/lib64/gfortran/modules/netcdf.mod \&\& test ! -f &|" models/utils/pio/configure

# --- Clone & install ExoCAM and ExoRT ---
# Install deps for ExoCAM py_progs
RUN dnf install -y pip && \
    /usr/bin/pip install netcdf4 scipy

# Also fix invalid XML caused by double hyphens `--` inside comments
RUN git clone https://github.com/storyofthewolf/ExoRT.git
RUN git clone https://github.com/storyofthewolf/ExoCAM.git && \
    cp ExoCAM/cesm1.2.1/ccsm_utils_files/{config_machines,config_compilers,env_mach_specific,mkbatch}.* ${CCSMROOT}/scripts/ccsm_utils/Machines && \
    sed -i "s|<\!-- complete path to the 'scratch'|complete path to the 'scratch'|" ${CCSMROOT}/scripts/ccsm_utils/Machines/config_machines.xml && \
    sed -i "s| ->| -->|" ${CCSMROOT}/scripts/ccsm_utils/Machines/config_machines.xml && \
    sed -i "s|------------------------------------------------------------------------||" ${CCSMROOT}/scripts/ccsm_utils/Machines/config_compilers.xml && \
    sed -i "s/--\(trace\|trap\|pca\|chk\)/- -\1/" ${CCSMROOT}/scripts/ccsm_utils/Machines/config_compilers.xml && \
    sed -i "s|<\!--  -g | -g |" ${CCSMROOT}/scripts/ccsm_utils/Machines/config_compilers.xml && \
    cp ExoCAM/cesm1.2.1/ccsm_utils_files/config_compsets.xml ${CCSMROOT}/scripts/ccsm_utils/Case.template && \
    cp ExoCAM/cesm1.2.1/ccsm_utils_files/namelist_definition.xml ${CCSMROOT}/models/atm/cam/bld/namelist_files && \
    cp ExoCAM/cesm1.2.1/ccsm_utils_files/namelist_definition_docn.xml ${CCSMROOT}/models/ocn/docn/bld/namelist_files && \
    find ExoCAM/cesm1.2.1/configs/ -type f -exec sed -i -e "s|/gpfsm/dnb53/etwolf/models|$HOME|" {} \; && \
    find ExoCAM/cesm1.2.1/ -type f -exec sed -i -e "s|/discover/nobackup/etwolf/models|$HOME|" {} \; && \
    find ExoRT/3dmodels/*/sys_rootdir.F90 -type f -exec sed -i "s|[^\!]character| !&|" {} \; && \
    find ExoRT/3dmodels/*/sys_rootdir.F90 -type f -exec sed -i "8i \\\n  ! Machine: docker\n  character(len=256), parameter :: exort_rootdir = '$HOME/ExoRT/'" {} \; && \
    sed -i "s|(/'H2O','CO2','CH4','C2H6','O3','O2'/)|(/'H2O ','CO2 ','CH4 ','C2H6','O3  ','O2  '/)|" /home/app/ExoRT/source/src.n68equiv/radgrid.F90 && \
    sed -i "s|(/'H2O','CO2','CH4','C2H6', 'O3', 'O2'/)|(/'H2O ','CO2 ','CH4 ','C2H6','O3  ','O2  '/)|" /home/app/ExoRT/source/src.n84equiv/radgrid.F90

# --- Create directories ---
RUN mkdir -p ${CCSMSHARED}/{baseline,cases,input,output,tests}

# --- Add "docker" machine/compiler config ---
COPY src/ccsm_utils_files/mkbatch.docker ${CCSMROOT}/scripts/ccsm_utils/Machines/mkbatch.docker
COPY src/ccsm_utils_files/env_mach_specific.docker ${CCSMROOT}/scripts/ccsm_utils/Machines/env_mach_specific.docker
COPY src/setup/ ${HOME}/setup

# --- Copy over exocam_setup bits & add to path ---
COPY src/bin/ ${HOME}/bin
ENV PATH=$PATH:$HOME/bin

# --- Finish setup & compile cprnc ---
RUN perl setup/add_docker_config.ps && \
    chmod 755 ${CCSMROOT}/scripts/ccsm_utils/Machines/mkbatch.docker && \
    chmod +x ${HOME}/bin/exocam_setup && \
    cd ${CCSMROOT}/tools/cprnc && \
    sed -i "165i OBJS += compare_vars_mod.o" Makefile && \
    gmake LIB_NETCDF=/usr/lib64 INC_NETCDF=/usr/include NETCDF=/usr USER_FC=gfortran LDFLAGS="-L/usr/lib64 -lnetcdff -lnetcdf" FFLAGS="-c -I/usr/include -I/usr/lib64/gfortran/modules -O -ffree-form -ffree-line-length-none"

CMD ["/bin/bash"]
