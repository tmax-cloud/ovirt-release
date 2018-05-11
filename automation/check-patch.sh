#!/bin/bash -xe
[[ -d exported-artifacts ]] \
|| mkdir -p exported-artifacts

[[ -d tmp.repos ]] \
|| mkdir -p tmp.repos

SUFFIX=".$(date -u +%Y%m%d%H%M%S).git$(git rev-parse --short HEAD)"

ARCH="$(rpm --eval "%_arch")"
DISTVER="$(rpm --eval "%dist"|cut -c2-3)"
PACKAGER=""
if [[ "${DISTVER}" == "el" ]]; then
    PACKAGER=yum
else
    PACKAGER=dnf
fi

autoreconf -ivf
./configure
make distcheck
rpmbuild \
    -D "_topdir $PWD/tmp.repos" \
    -D "release_suffix ${SUFFIX}" \
    -ta ovirt-release*.tar.gz

mv *.tar.gz exported-artifacts
find \
    "$PWD/tmp.repos" \
    -iname \*.rpm \
    -exec mv {} exported-artifacts/ \;
pushd exported-artifacts
    #Restoring sane yum environment
    rm -f /etc/yum.conf
    ${PACKAGER} reinstall -y system-release ${PACKAGER}
    [[ -d /etc/dnf ]] && [[ -x /usr/bin/dnf ]] && dnf -y reinstall dnf-conf
    [[ -d /etc/dnf ]] && sed -i -re 's#^(reposdir *= *).*$#\1/etc/yum.repos.d#' '/etc/dnf/dnf.conf'
    ${PACKAGER} install -y ovirt-release-master-4*noarch.rpm
    rm -f /etc/yum/yum.conf
    DISTVER="$(rpm --eval "%dist"|cut -c2-)"
    if [[ "${DISTVER}" == "el7.centos" ]]; then
        #Enable CR repo
        sed -i "s:enabled=0:enabled=1:" /etc/yum.repos.d/CentOS-CR.repo
    fi
    ${PACKAGER} repolist enabled

    ${PACKAGER} clean all
    if [[ "${DISTVER}" == "fc27" ]]; then
        # Fedora 27 support is broken, just provide a hint on what's missing
        # without causing the test to fail.
        ${PACKAGER} --downloadonly install *noarch.rpm || true
    elif [[ "${DISTVER}" == "fc28" ]]; then
        # Fedora 28 support is broken, just provide a hint on what's missing
        # without causing the test to fail.
        ${PACKAGER} --downloadonly install *noarch.rpm || true
    else
        ${PACKAGER} --downloadonly install *noarch.rpm
        if [[ "${ARCH}" == "x86_64" ]]; then
            ${PACKAGER} --downloadonly install ovirt-engine
        fi
    fi
popd

