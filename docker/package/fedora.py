# SPDX-FileCopyrightText: 2021 Oxhead Alpha
# SPDX-License-Identifier: LicenseRef-MIT-OA
import os, shutil, subprocess

from typing import List

from .model import AbstractPackage
from .systemd import print_service_file


def build_fedora_package(
    pkg: AbstractPackage,
    build_deps: List[str],
    run_deps: List[str],
    is_source: bool,
    binaries_dir: str = None,
):
    version = pkg.meta.version.replace("-", "")
    dir = f"{pkg.name}-{version}"
    cwd = os.path.dirname(__file__)
    home = os.environ["HOME"]

    pkg.fetch_sources(dir, binaries_dir)
    pkg.gen_buildfile("/".join([dir, pkg.buildfile]), binaries_dir)
    pkg.gen_license(f"{dir}/LICENSE")
    for systemd_unit in pkg.systemd_units:
        # lowercase package name for consistency between different os
        name_lower = pkg.name.lower()
        if systemd_unit.service_file.service.environment_files is not None:
            systemd_unit.service_file.service.environment_files = [
                x.lower() for x in systemd_unit.service_file.service.environment_files
            ]
        if systemd_unit.suffix is None:
            unit_name = name_lower
        else:
            unit_name = f"{name_lower}-{systemd_unit.suffix}"
        out_path = (
            f"{dir}/{unit_name}@.service"
            if systemd_unit.instances is not None
            else f"{dir}/{unit_name}.service"
        )
        print_service_file(systemd_unit.service_file, out_path)
        if systemd_unit.config_file is not None:
            default_name = (
                unit_name if systemd_unit.instances is None else f"{unit_name}@"
            )
            default_path = f"{dir}/{default_name}.default"
            shutil.copy(f"{cwd}/defaults/{systemd_unit.config_file}", default_path)
            if systemd_unit.config_file_append is not None:
                with open(default_path, "a") as def_file:
                    def_file.write("\n".join(systemd_unit.config_file_append))

        for script, script_source in [
            (systemd_unit.startup_script, systemd_unit.startup_script_source),
            (systemd_unit.prestart_script, systemd_unit.prestart_script_source),
            (systemd_unit.poststop_script, systemd_unit.poststop_script_source),
        ]:
            if script is not None:
                dest_path = f"{dir}/{script}"
                source_script_name = script if script_source is None else script_source
                source_path = f"{cwd}/scripts/{source_script_name}"
                shutil.copy(source_path, dest_path)
    subprocess.run(["tar", "-czf", f"{dir}.tar.gz", dir], check=True)
    os.makedirs(f"{home}/rpmbuild/SPECS", exist_ok=True)
    os.makedirs(f"{home}/rpmbuild/SOURCES", exist_ok=True)
    pkg.gen_spec_file(
        build_deps + run_deps, run_deps, f"{home}/rpmbuild/SPECS/{pkg.name}.spec"
    )
    os.rename(f"{dir}.tar.gz", f"{home}/rpmbuild/SOURCES/{dir}.tar.gz")
    subprocess.run(
        [
            "rpmbuild",
            "-bs" if is_source else "-bb",
            f"{home}/rpmbuild/SPECS/{pkg.name}.spec",
        ],
        check=True,
    )

    subprocess.run(f"rm -rf {dir}", shell=True, check=True)
