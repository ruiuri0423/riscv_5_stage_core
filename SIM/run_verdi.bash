#!/bin/bash
# `verdi` is a real binary on PATH and VERDI_HOME/NOVAS_HOME are exported in
# ~/.bashrc, so they are inherited from the calling shell (no `-i` needed here,
# unlike run_vcs.bash which relies on the `vcs` alias).

verdi -sv -f ./flist.f