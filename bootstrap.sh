#!/usr/bin/env bash

if [[ "$1" == "zsh" ]]; then
    cat <<EOF > shell
#!/usr/bin/env zsh

export INSTALL_LOC=/srv/
export ZDOTDIR=\$INSTALL_LOC

EOF
else
    cat <<EOF > shell
#!/usr/bin/env bash

export INSTALL_LOC=/srv/

EOF
fi

if [[ "$2" == "lpc" ]]; then
    cat <<EOF >> shell
# Needed to setup cluster for LPC
export CONDOR_CONFIG=\$INSTALL_LOC.condor_config
grep -v '^include' /etc/condor/config.d/01_cmslpc_interactive > .condor_config

# Need all our bind addresses
export APPTAINER_BINDPATH=/uscmst1b_scratch,/cvmfs,/cvmfs/grid.cern.ch/etc/grid-security:/etc/grid-security,/eos,/etc/pki/ca-trust,/run/user,/var/run/user,/eos

EOF
else
    cat <<EOF >> shell
# Need all our bind addresses
export APPTAINER_BINDPATH=/cvmfs,/cvmfs/grid.cern.ch/etc/grid-security:/etc/grid-security,/eos,/etc/pki/ca-trust,/etc/tnsnames.ora,/run/user,/var/run/user,/eos

EOF
fi

cat <<EOF >> shell
voms-proxy-init -voms cms --valid 192:00 --out \$HOME/x509up_u\$UID

if [[ "\$1" == "" ]]; then
  export COFFEA_IMAGE="coffeateam/coffea-dask-almalinux8:2024.11.0-py3.12"
  # export COFFEA_IMAGE=/cvmfs/unpacked.cern.ch/registry.hub.docker.com/coffeateam/coffea-dask:latest
else
  export COFFEA_IMAGE=\$1
fi

export FULL_IMAGE="/cvmfs/unpacked.cern.ch/registry.hub.docker.com/"\$COFFEA_IMAGE
EOF

if [[ "$1" == "zsh" ]]; then
    cat <<EOF >> shell
SINGULARITY_SHELL=\$(which zsh) singularity exec -B \${PWD}:/srv --pwd /srv \${FULL_IMAGE} $(which zsh)
EOF
else
    cat <<EOF >> shell
SINGULARITY_SHELL=\$(which bash) singularity exec -B \${PWD}:/srv --pwd /srv \${FULL_IMAGE} $(which bash) --rcfile /srv/.bashrc
EOF
fi

cat <<EOF > .bashrc
LPCJQ_VERSION="0.4.1"
install_env() {
  set -e
  echo "Installing shallow virtual environment in \$INSTALL_LOC..env..."
  python -m venv --without-pip --system-site-packages \$INSTALL_LOC..env
  unlink .env/lib64  # HTCondor can't transfer symlink to directory and it appears optional
  # work around issues copying CVMFS xattr when copying to tmpdir
  export TMPDIR=\$(mktemp -d -p .)
  rm -rf \$TMPDIR && unset TMPDIR
  # \$INSTALL_LOC..env/bin/python -m pip install --upgrade awkward dask_awkward coffea uproot
  cd processing
  \$INSTALL_LOC.env/bin/python -m pip install -e .
  cd ..
  \$INSTALL_LOC.env/bin/python -m pip install -q git+https://github.com/CoffeaTeam/lpcjobqueue.git@v\${LPCJQ_VERSION}
  echo "done."
}

install_kernel() {
  # work around issues copying CVMFS xattr when copying to tmpdir
  export TMPDIR=\$(mktemp -d -p .)
  \$INSTALL_LOC.env/bin/python -m ipykernel install --user --name monoz --display-name "monoz" --env PYTHONPATH $PYTHONPATH:$PWD --env PYTHONNOUSERSITE 1
  rm -rf \$TMPDIR && unset TMPDIR
}

install_all() {
  install_env
  install_kernel
}

export JUPYTER_PATH=\$INSTALL_LOC.jupyter
export JUPYTER_RUNTIME_DIR=\$INSTALL_LOC.local/share/jupyter/runtime
export JUPYTER_DATA_DIR=\$INSTALL_LOC.local/share/jupyter
export IPYTHONDIR=\$INSTALL_LOC.ipython
unset GREP_OPTIONS

[[ -d \$INSTALL_LOC.env ]] || install_all
source \$INSTALL_LOC.env/bin/activate
alias pip="python -m pip"
voms-proxy-init -voms cms -vomses /etc/grid-security/vomses/ --valid 192:00 --out \$HOME/x509up_u\$UID
# pip show lpcjobqueue 2>/dev/null | grep -q "Version: \${LPCJQ_VERSION}" || pip install -q git+https://github.com/CoffeaTeam/lpcjobqueue.git@v\${LPCJQ_VERSION}
EOF

cat <<EOF > .zshrc

LPCJQ_VERSION="0.4.1"
install_env() {
  set -e
  echo "Installing shallow virtual environment in \$INSTALL_LOC.env..."
  python -m venv --without-pip --system-site-packages \$INSTALL_LOC.env
  unlink .env/lib64  # HTCondor can't transfer symlink to directory and it appears optional
  # work around issues copying CVMFS xattr when copying to tmpdir
  export TMPDIR=\$(mktemp -d -p .)
  rm -rf \$TMPDIR && unset TMPDIR
  # \$INSTALL_LOC.env/bin/python -m pip install --upgrade awkward dask_awkward coffea uproot
  cd processing
  \$INSTALL_LOC.env/bin/python -m pip install -e .
  cd ..
  \$INSTALL_LOC.env/bin/python -m pip install -q git+https://github.com/CoffeaTeam/lpcjobqueue.git@v\${LPCJQ_VERSION}
  echo "done."
}

install_kernel() {
  # work around issues copying CVMFS xattr when copying to tmpdir
  export TMPDIR=\$(mktemp -d -p .)
  \$INSTALL_LOC.env/bin/python -m ipykernel install --user --name monoz --display-name "monoz" --env PYTHONPATH $PYTHONPATH:$PWD --env PYTHONNOUSERSITE 1
  rm -rf \$TMPDIR && unset TMPDIR
}

install_all() {
  install_env
  install_kernel
}

export JUPYTER_PATH=\$INSTALL_LOC.jupyter
export JUPYTER_RUNTIME_DIR=\$INSTALL_LOC.local/share/jupyter/runtime
export JUPYTER_DATA_DIR=\$INSTALL_LOC.local/share/jupyter
export IPYTHONDIR=\$INSTALL_LOC.ipython
unset GREP_OPTIONS

[[ -d \$INSTALL_LOC.env ]] || install_all
source \$INSTALL_LOC.env/bin/activate
alias pip="python -m pip"
voms-proxy-init -voms cms -vomses /etc/grid-security/vomses/ --valid 192:00 --out \$HOME/x509up_u\$UID
# pip show lpcjobqueue 2>/dev/null | grep -q "Version: \${LPCJQ_VERSION}" || pip install -q git+https://github.com/CoffeaTeam/lpcjobqueue.git@v\${LPCJQ_VERSION}
EOF

chmod u+x shell .bashrc .zshrc
echo "Wrote shell .bashrc and .zshrc to current directory. Run ./shell to start the singularity shell"
