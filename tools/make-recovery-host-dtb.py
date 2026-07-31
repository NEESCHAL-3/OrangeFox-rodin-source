#!/usr/bin/env python3

import argparse
import pathlib
import shutil
import struct
import subprocess
import tempfile


CONTAINER_MAGIC = bytes.fromhex("d7b7ab1e")
FDT_MAGIC = bytes.fromhex("d00dfeed")

TOTAL_LENGTH_FIELD = 4
FDT_LENGTH_FIELD = 32
FDT_START_FIELD = 36

TARGET_NODE = "/soc/usb0@11201000/xhci0@11200000"
TARGET_PROPERTY = "mediatek,usb-offload"


class DtbError(RuntimeError):
    pass


def be32(blob: bytes, offset: int) -> int:
    if offset + 4 > len(blob):
        raise DtbError(f"field outside input at offset {offset}")

    return struct.unpack_from(">I", blob, offset)[0]


def inspect_container(blob: bytes) -> tuple[int, int]:
    if len(blob) < 64:
        raise DtbError("input is too small for a MediaTek DTB container")

    if blob[:4] != CONTAINER_MAGIC:
        raise DtbError("input does not have the expected MediaTek container magic")

    recorded_total = be32(blob, TOTAL_LENGTH_FIELD)
    fdt_length = be32(blob, FDT_LENGTH_FIELD)
    fdt_start = be32(blob, FDT_START_FIELD)

    if recorded_total != len(blob):
        raise DtbError(
            f"container length mismatch: header={recorded_total}, actual={len(blob)}"
        )

    if fdt_start < 64:
        raise DtbError(f"invalid embedded-FDT offset: {fdt_start}")

    if fdt_length <= 0 or fdt_start + fdt_length > len(blob):
        raise DtbError(
            f"invalid embedded-FDT range: start={fdt_start}, length={fdt_length}"
        )

    if blob[fdt_start:fdt_start + 4] != FDT_MAGIC:
        raise DtbError("declared embedded payload is not an FDT")

    return fdt_start, fdt_length


def property_exists(fdtget: str, dtb: pathlib.Path) -> bool:
    result = subprocess.run(
        [fdtget, "-t", "x", str(dtb), TARGET_NODE, TARGET_PROPERTY],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )

    return result.returncode == 0


def decompile(dtc: str, dtb: pathlib.Path, output: pathlib.Path) -> str:
    subprocess.run(
        [dtc, "-q", "-I", "dtb", "-O", "dts", "-o", str(output), str(dtb)],
        check=True,
    )

    return output.read_text(errors="strict")


def remove_target_statement(dts: str) -> str:
    result: list[str] = []
    dropping = False

    for line in dts.splitlines():
        if not dropping and TARGET_PROPERTY in line:
            dropping = ";" not in line
            continue

        if dropping:
            if ";" in line:
                dropping = False
            continue

        result.append(line.rstrip())

    return "\n".join(result).strip()


def build_recovery_dtb(source: pathlib.Path, destination: pathlib.Path) -> None:
    tools = {
        name: shutil.which(name)
        for name in ("dtc", "fdtget", "fdtput")
    }

    missing = [name for name, path in tools.items() if not path]

    if missing:
        raise DtbError("missing host tools: " + ", ".join(missing))

    original = source.read_bytes()
    fdt_start, fdt_length = inspect_container(original)

    prefix = bytearray(original[:fdt_start])
    embedded = original[fdt_start:fdt_start + fdt_length]
    suffix = original[fdt_start + fdt_length:]

    with tempfile.TemporaryDirectory(prefix="rodin-recovery-dtb-") as temp:
        work = pathlib.Path(temp)

        before = work / "before.dtb"
        after = work / "after.dtb"
        before_dts = work / "before.dts"
        after_dts = work / "after.dts"

        before.write_bytes(embedded)
        after.write_bytes(embedded)

        if not property_exists(tools["fdtget"], before):
            raise DtbError(
                f"{TARGET_PROPERTY} is absent from the protected stock DTB"
            )

        subprocess.run(
            [
                tools["fdtput"],
                "-d",
                str(after),
                TARGET_NODE,
                TARGET_PROPERTY,
            ],
            check=True,
        )

        if property_exists(tools["fdtget"], after):
            raise DtbError(f"failed to delete {TARGET_PROPERTY}")

        compatible = subprocess.run(
            [
                tools["fdtget"],
                "-t",
                "s",
                str(after),
                TARGET_NODE,
                "compatible",
            ],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
        ).stdout.strip()

        if compatible != "mediatek,mtk-xhci":
            raise DtbError(
                f"unexpected xHCI compatible value after edit: {compatible!r}"
            )

        before_text = decompile(tools["dtc"], before, before_dts)
        after_text = decompile(tools["dtc"], after, after_dts)

        if remove_target_statement(before_text) != remove_target_statement(after_text):
            raise DtbError(
                "semantic DTB comparison found changes beyond the target property"
            )

        patched_fdt = after.read_bytes()

    final_length = len(prefix) + len(patched_fdt) + len(suffix)

    struct.pack_into(">I", prefix, TOTAL_LENGTH_FIELD, final_length)
    struct.pack_into(">I", prefix, FDT_LENGTH_FIELD, len(patched_fdt))

    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(prefix + patched_fdt + suffix)

    completed = destination.read_bytes()
    check_start, check_length = inspect_container(completed)

    if check_start != fdt_start or check_length != len(patched_fdt):
        raise DtbError("final container verification failed")

    print(f"input_size={len(original)}")
    print(f"embedded_offset={fdt_start}")
    print(f"embedded_size_before={fdt_length}")
    print(f"embedded_size_after={len(patched_fdt)}")
    print(f"output_size={len(completed)}")
    print(f"removed={TARGET_NODE}:{TARGET_PROPERTY}")
    print("semantic_change=target-property-only")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create a rodin recovery DTB without Android USB-offload coupling."
    )
    parser.add_argument("source", type=pathlib.Path)
    parser.add_argument("destination", type=pathlib.Path)
    arguments = parser.parse_args()

    try:
        build_recovery_dtb(arguments.source, arguments.destination)
    except (
        DtbError,
        OSError,
        subprocess.CalledProcessError,
    ) as error:
        print(f"RECOVERY_DTB_ERROR: {error}")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
